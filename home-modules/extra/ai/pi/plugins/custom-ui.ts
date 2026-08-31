// custom-ui: custom tool rendering for pi's built-in tools,
// owned here outright (pi gives tool-name ownership to the first extension
// that registers; this extension loads before nix-comma, so it wins `bash`).
//
// One-line calls (`● edit src/foo.ts`), one-line result summaries
// (`⎿  +12 −3`, `⎿  42 lines`), no boxes — full output on demand via
// ctrl+o. Render slots live in lib/custom-ui.ts.
//
// Also owns the `read` tool with inline kitty-placeholder image rendering
// (merged from image-history.ts): user-message images, history fallback
// cells, and tool-result images inside the read row.
//
// User messages and `!` shell commands get the zentui-style compact look
// (accent rail + base01 band, no box) via prototype patches of
// UserMessageComponent / BashExecutionComponent (see below).
//
// Other extensions opt in voluntarily via the __piCustomUi runtime API
// (no lib import, no load-order coupling):
//   const api = (globalThis as any).__piCustomUi;
//   pi.registerTool(api?.maybeDecorate(myTool, { label: "My Tool", argOf: (a) => a.path }) ?? myTool);
// Registration order: the API installs when this extension loads, which is
// before user extensions (alphabetical in ~/.pi/agent/extensions), so the
// simple `api?.maybeDecorate(...) ?? myTool` form is always safe here.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
	BashExecutionComponent,
	InteractiveMode,
	type ExtensionAPI,
	type Theme,
	UserMessageComponent,
} from "@earendil-works/pi-coding-agent";
import {
	convertToPng,
	createBashToolDefinition,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadToolDefinition,
	createWriteTool,
	resizeImage,
} from "@earendil-works/pi-coding-agent";
import {
	attachNotes,
	bash,
	collapseToolGroup,
	genericSlots,
	customUiEnabled,
	DOTS_SPINNERS,
	edit,
	base16Bg,
	base16Fg,
	find,
	foldToolGroup,
	glanceLine,
	groupMode,
	grep,
	latestCap,
	ls,
	pushToolNote,
	readCallSlot,
	readTextResult,
	scanToolGroupsFromHistory,
	currentBatchSize,
	settleStatus,
	shimmerFrame,
	tickOpenBatch,
	animState,
	trackGroupToolCall,
	write,
} from "./lib/custom-ui.ts";
import {
	calculateImageRows,
	Container,
	getCapabilities,
	getCellDimensions,
	getImageDimensions,
	Loader,
	type Component,
	type ImageProtocol,
	Text,
	truncateToWidth,
	visibleWidth,
} from "@earendil-works/pi-tui";

type HistoryImage = { data: string; mimeType: string };

// History thumbnails don't need model-grade fidelity — cap the encoded size.
const HISTORY_MAX_DIMENSION = 800;
const HISTORY_MAX_BYTES = 3 * 1024 * 1024;
// PNGs at or below this base64 length are already small (e.g. pi-image-view's
// 480px preview thumbnails) — skip resizing entirely.
const SMALL_PNG_BASE64_BYTES = 512 * 1024;
// Max on-screen size of a history image, in terminal cells.
const MAX_WIDTH_CELLS = 44;
const MAX_ROWS = 15;
// Collapsed text preview length for the read renderResult override (mirrors
// pi's built-in tool result fallback).
const FALLBACK_PREVIEW_LINES = 10;

// pi-image-view persists submission previews under ~/.pi/agent/image-view/
// blobs/ and links them from the message text as
// `[[Image #N]](file:///…/image-view/blobs/<sha256>.png)` (single brackets
// before its own transformer runs). Only PNG previews can be shown inline:
// kitty's f=100 transmission requires PNG.
const BLOB_MARKER_SOURCE =
	"\\[{1,2}Image #\\d+\\]{1,2}\\((file:\\/\\/\\/[^)\\n]*\\/image-view\\/blobs\\/[a-f0-9]{64}\\.png)\\)";
const BLOB_MARKER_RE = new RegExp(BLOB_MARKER_SOURCE, "g");
const BLOB_MARKER_TEST_RE = new RegExp(BLOB_MARKER_SOURCE);

function messageHasBlobMarker(message: { content?: unknown }): boolean {
	const content = message.content;
	if (typeof content === "string") return BLOB_MARKER_TEST_RE.test(content);
	if (!Array.isArray(content)) return false;
	return content.some(
		(part) =>
			part !== null && typeof part === "object" &&
			typeof (part as { text?: unknown }).text === "string" &&
			BLOB_MARKER_TEST_RE.test((part as { text: string }).text),
	);
}

// ── Protocol detection (pi-tui returns null under tmux) ────

function detectImageProtocol(): ImageProtocol {
	const caps = getCapabilities();
	if (caps.images) return caps.images;

	// pi-tui returns null inside tmux — check if the outer terminal is kitty.
	const inTmux = Boolean(process.env.TMUX) || (process.env.TERM?.toLowerCase() || "").startsWith("tmux");
	if (!inTmux) return null;
	if (process.env.KITTY_WINDOW_ID || (process.env.TERM_PROGRAM?.toLowerCase() || "") === "kitty") return "kitty";
	const termProgram = process.env.TERM_PROGRAM?.toLowerCase() || "";
	if (termProgram === "ghostty" || process.env.GHOSTTY_RESOURCES_DIR) return "kitty";
	if (termProgram === "wezterm" || process.env.WEZTERM_PANE) return "kitty";
	return null;
}

// ── Kitty Unicode placeholder transmission ──────────────────

const PLACEHOLDER_CHAR = String.fromCodePoint(0x10eeee);
const GAP = " ";

// Row/column diacritics from kitty's rowcolumn-diacritics.txt
const ROW_COL_DIACRITICS = [
	0x0305, 0x030d, 0x030e, 0x0310, 0x0312, 0x033d, 0x033e, 0x033f,
	0x0346, 0x034a, 0x034b, 0x034c, 0x0350, 0x0351, 0x0352, 0x0353,
	0x0357, 0x035b, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368,
	0x0369, 0x036a, 0x036b, 0x036c, 0x036d, 0x036e, 0x036f, 0x0483,
	0x0484, 0x0485, 0x0486, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597,
	0x0598, 0x0599, 0x059c, 0x059d, 0x059e, 0x059f, 0x05a0, 0x05a1,
	0x05a8, 0x05a9, 0x05ab, 0x05ac, 0x05af, 0x05c4, 0x0610, 0x0611,
	0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0618, 0x0619,
	0x061a, 0x064b, 0x064c, 0x064d, 0x064e, 0x064f, 0x0650, 0x0651,
	0x0652, 0x0653, 0x0654, 0x0655, 0x0656, 0x0657, 0x0658, 0x0659,
	0x065a, 0x065b, 0x065c, 0x065d, 0x065e, 0x065f, 0x0670, 0x06d6,
	0x06d7, 0x06d8, 0x06d9, 0x06da, 0x06db, 0x06dc, 0x06df, 0x06e0,
	0x06e1, 0x06e2, 0x06e3, 0x06e4, 0x06e7, 0x06e8, 0x06ea, 0x06eb,
	0x06ec, 0x06ed,
];

function diacriticFor(n: number): string {
	return String.fromCodePoint(ROW_COL_DIACRITICS[n] ?? ROW_COL_DIACRITICS[0]!);
}

/** Wrap kitty APC sequences in DCS passthrough for tmux. */
function wrapForTmux(sequence: string): string {
	if (!process.env.TMUX) return sequence;
	return sequence.replace(
		/\x1b_G([^\x1b]*)\x1b\\/g,
		(_match, content) => `\x1bPtmux;\x1b\x1b_G${content}\x1b\x1b\\\x1b\\`,
	);
}

function transmitImage(base64Data: string, imageId: number, columns: number, rows: number): void {
	const controls = `a=T,U=1,f=100,i=${imageId},c=${columns},r=${rows},q=2`;
	const CHUNK_SIZE = 4096;
	if (base64Data.length <= CHUNK_SIZE) {
		process.stdout.write(wrapForTmux(`\x1b_G${controls};${base64Data}\x1b\\`));
		return;
	}
	let offset = 0;
	let first = true;
	while (offset < base64Data.length) {
		const chunk = base64Data.slice(offset, offset + CHUNK_SIZE);
		const last = offset + CHUNK_SIZE >= base64Data.length;
		const more = last ? "m=0" : "m=1";
		const head = first ? `${controls},${more}` : more;
		process.stdout.write(wrapForTmux(`\x1b_G${head};${chunk}\x1b\\`));
		first = false;
		offset += CHUNK_SIZE;
	}
}

/**
 * One row of placeholder cells for an image. The foreground color encodes the
 * image ID; the first cell's combining diacritics encode the row, and kitty
 * auto-increments the column from there.
 */
function placeholderRow(imageId: number, row: number, columns: number): string {
	const r = (imageId >> 16) & 0xff;
	const g = (imageId >> 8) & 0xff;
	const b = imageId & 0xff;
	const fgStart = imageId < 256 ? `\x1b[38;5;${imageId}m` : `\x1b[38;2;${r};${g};${b}m`;
	return `${fgStart}${PLACEHOLDER_CHAR}${diacriticFor(row)}${diacriticFor(0)}${PLACEHOLDER_CHAR.repeat(columns - 1)}\x1b[39m`;
}

// Content-hashed 24-bit kitty IDs: stable across re-renders, so a re-render
// with the same geometry replaces the data instead of uploading a new image.
function imageIdFor(data: string): number {
	const hash = createHash("sha256").update(data).digest();
	const id = ((hash[0]! << 16) | (hash[1]! << 8) | hash[2]!) & 0xffffff;
	return id === 0 ? 1 : id;
}

// Images already transmitted at a given geometry this session. A width change
// re-transmits (key includes cols/rows) so images survive terminal resizes.
const transmitted = new Set<string>();

// ── Shared render core ─────────────────────────────────────

/**
 * Build the placeholder lines for one image at the given width, transmitting
 * the pixels to kitty first if this geometry hasn't been sent yet. Shared by
 * the markdown transformer (inline in the message) and the entry renderer
 * (fallback block below the message).
 */
function imageLines(base64Png: string, columns: number): string[] {
	const dims = getImageDimensions(base64Png, "image/png") ?? { widthPx: 800, heightPx: 600 };
	const cellDims = getCellDimensions();
	let rows = calculateImageRows(dims, columns, cellDims);
	if (rows > MAX_ROWS) {
		// Cap height by shrinking width proportionally — a grid wider/taller than
		// the image's aspect would letterbox the image with dead placeholder cells.
		columns = Math.max(
			4,
			Math.floor((columns * MAX_ROWS) / rows),
		);
		rows = calculateImageRows(dims, columns, cellDims);
	}
	const imageId = imageIdFor(base64Png);

	const key = `${imageId}:${columns}x${rows}`;
	if (!transmitted.has(key)) {
		transmitImage(base64Png, imageId, columns, rows);
		transmitted.add(key);
	}

	const lines: string[] = [];
	for (let row = 0; row < rows; row += 1) {
		lines.push(GAP + placeholderRow(imageId, row, columns));
	}
	return lines;
}

function clampColumns(availableWidth: number): number {
	return Math.max(4, Math.min(availableWidth - 2, MAX_WIDTH_CELLS));
}

// ── Inline transformer ──────────────────────────────────────

// Blob files are immutable; cache their base64 so re-renders don't re-read.
const blobCache = new Map<string, string>();

function loadBlob(fileUrl: string): string | undefined {
	const cached = blobCache.get(fileUrl);
	if (cached) return cached;
	try {
		const data = readFileSync(fileURLToPath(fileUrl)).toString("base64");
		blobCache.set(fileUrl, data);
		return data;
	} catch {
		return undefined;
	}
}

function transformUserMarkdown(markdown: string, availableWidth: number): string {
	return markdown.replace(BLOB_MARKER_RE, (match, fileUrl: string, offset: number, full: string) => {
		const data = loadBlob(fileUrl);
		if (!data) return match;
		// The rows must each occupy a full line of their own: sharing a line with
		// text pushes the run past the wrap width, and splitting a placeholder run
		// mid-row breaks the placement (orphan cells render as dark blocks).
		const rows = imageLines(data, clampColumns(availableWidth)).join("\n");
		const dims = getImageDimensions(data, "image/png");
		const caption = dims ? `${dims.widthPx}×${dims.heightPx}` : "";
		const needsBreakBefore = offset > 0 && full[offset - 1] !== "\n";
		const after = offset + match.length;
		const needsBreakAfter = after < full.length && full[after] !== "\n";
		return `${needsBreakBefore ? "\n" : ""}${caption ? `${caption}\n` : ""}${rows}${needsBreakAfter ? "\n" : ""}`;
	});
}

// ── Entry fallback (images without blob markers) ───────────

class HistoryImageCell implements Component {
	private readonly image: HistoryImage;
	private readonly fallbackColor: (s: string) => string;
	private readonly autoPrepare: boolean;
	private readonly onPrepared?: () => void;
	private prepared?: HistoryImage;
	private prepareStarted = false;
	private cachedLines?: string[];
	private cachedWidth?: number;

	constructor(
		image: HistoryImage,
		fallbackColor: (s: string) => string,
		opts?: { autoPrepare?: boolean; onPrepared?: () => void },
	) {
		this.image = image;
		this.fallbackColor = fallbackColor;
		this.autoPrepare = opts?.autoPrepare ?? false;
		this.onPrepared = opts?.onPrepared;
	}

	invalidate(): void {
		this.cachedLines = undefined;
		this.cachedWidth = undefined;
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;

		const protocol = detectImageProtocol();
		if (protocol !== null && this.autoPrepare && !this.prepareStarted) {
			// Non-PNG payloads (kitty needs PNG) and oversized PNGs are converted/
			// downsampled asynchronously; show the text fallback until ready.
			this.prepareStarted = true;
			void preparedHistoryImage(this.image).then((prepared) => {
				this.prepared = prepared;
				this.invalidate();
				this.onPrepared?.();
			});
		}

		const active = this.prepared ?? this.image;
		if (protocol === null || active.mimeType !== "image/png") {
			const dims = getImageDimensions(active.data, active.mimeType);
			const size = dims ? ` ${dims.widthPx}x${dims.heightPx}` : "";
			this.cachedLines = [this.fallbackColor(`[Image: ${active.mimeType}${size}]`)];
			this.cachedWidth = width;
			return this.cachedLines;
		}

		this.cachedLines = imageLines(active.data, clampColumns(width));
		this.cachedWidth = width;
		return this.cachedLines;
	}
}

// ── Newest image-carrying read ─────────────

// Collapsed `read` rows hide their images unless they are the newest read
// that returned one (expanded rows always show them). Tracked live via
// tool_call/tool_result events and rebuilt from session history on
// session_start so restored sessions behave the same. The image therefore
// stays visible until a newer image read replaces it — plain text reads
// don't evict it.

function imagesInContent(content: unknown): number {
	if (!Array.isArray(content)) return 0;
	return content.filter(
		(part) =>
			part !== null && typeof part === "object" &&
			(part as { type?: unknown }).type === "image" &&
			typeof (part as { data?: unknown }).data === "string" &&
			(part as { data: string }).data.length > 0,
	).length;
}

// "Newest" is decided by CALL order (= display order in the TUI), never by
// event arrival: parallel reads settle out of order, so the last tool_result
// event is not necessarily the last row on screen.
let readCallCounter = 0;
const readCallOrder = new Map<string, number>();
const imageReadCallIds = new Set<string>();

function newestImageReadCallId(): string | undefined {
	let newest: string | undefined;
	for (const id of imageReadCallIds) {
		if (newest === undefined || (readCallOrder.get(id) ?? 0) > (readCallOrder.get(newest) ?? 0)) {
			newest = id;
		}
	}
	return newest;
}

function trackReadCall(toolCallId: string): void {
	readCallOrder.set(toolCallId, ++readCallCounter);
}

function trackReadResult(toolCallId: string, content: unknown): void {
	if (imagesInContent(content) > 0) imageReadCallIds.add(toolCallId);
}

function resetReadTracking(): void {
	readCallCounter = 0;
	readCallOrder.clear();
	imageReadCallIds.clear();
}

function scanHistoryForReadTracking(entries: Iterable<{ type: string; message?: unknown }>): void {
	resetReadTracking();
	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const message = entry.message as { role?: unknown; toolCallId?: unknown; toolName?: unknown; content?: unknown } | undefined;
		if (!message) continue;
		if (message.role === "assistant" && Array.isArray(message.content)) {
			// toolCall blocks appear in call order within one assistant message.
			for (const part of message.content) {
				if (
					part !== null && typeof part === "object" &&
					(part as { type?: unknown }).type === "toolCall" &&
					(part as { name?: unknown }).name === "read" &&
					typeof (part as { id?: unknown }).id === "string"
				) {
					trackReadCall((part as { id: string }).id);
				}
			}
		} else if (
			message.role === "toolResult" &&
			message.toolName === "read" &&
			typeof message.toolCallId === "string"
		) {
			trackReadResult(message.toolCallId, message.content);
		}
	}
}

// ── Extension ───────────────────────────────────────────────

function imagesInMessage(message: { role?: unknown; content?: unknown }): HistoryImage[] {
	if (message.role !== "user" || !Array.isArray(message.content)) return [];
	const images: HistoryImage[] = [];
	for (const part of message.content) {
		if (!part || typeof part !== "object") continue;
		const { type, data, mimeType } = part as { type?: unknown; data?: unknown; mimeType?: unknown };
		if (type === "image" && typeof data === "string" && data.length > 0 && typeof mimeType === "string") {
			images.push({ data, mimeType });
		}
	}
	return images;
}

// pi rebuilds tool-row component trees on every invalidate (new tool calls
// shifting the "latest" group, expand toggles, width changes, streaming
// partials). Each rebuild used to construct fresh HistoryImageCells, and every
// fresh cell re-ran the full prepare pipeline — spawn resize worker, decode the
// multi-MB original in Photon WASM, re-encode PNG/JPEG candidates, copy base64 —
// for the SAME image. In image-heavy sessions that allocation rate outpaced GC
// and OOM'd V8 at its ~4 GB heap cap. Cache prepared results by content hash so
// the pipeline runs once per unique image, not once per render.
const preparedCache = new Map<string, Promise<HistoryImage>>();
const PREPARED_CACHE_MAX = 64;

function preparedHistoryImage(image: HistoryImage): Promise<HistoryImage> {
	// Hash + length: cheap, and collisions on a 24-bit id are practically
	// excluded by also keying on the exact payload size.
	const key = `${imageIdFor(image.data)}:${image.data.length}`;
	let cached = preparedCache.get(key);
	if (!cached) {
		cached = toHistoryImage(image);
		if (preparedCache.size >= PREPARED_CACHE_MAX) {
			const oldest = preparedCache.keys().next().value;
			if (oldest !== undefined) preparedCache.delete(oldest);
		}
		preparedCache.set(key, cached);
		// Don't cache rejected prepares — let the next render retry.
		cached.catch(() => preparedCache.delete(key));
	}
	return cached;
}

async function toHistoryImage(image: HistoryImage): Promise<HistoryImage> {
	if (image.mimeType === "image/png" && image.data.length <= SMALL_PNG_BASE64_BYTES) return image;
	try {
		const resized = await resizeImage(Buffer.from(image.data, "base64"), image.mimeType, {
			maxWidth: HISTORY_MAX_DIMENSION,
			maxHeight: HISTORY_MAX_DIMENSION,
			maxBytes: HISTORY_MAX_BYTES,
		});
		const source = resized ?? image;
		const png = await convertToPng(source.data, source.mimeType);
		const final = png ?? source;
		return { data: final.data, mimeType: final.mimeType };
	} catch {
		return image;
	}
}


const readInvalidators = new Map<string, () => void>();

function evictPreviouslyNewest(previous: string | undefined, current: string): void {
	if (!previous || previous === current) return;
	const invalidate = readInvalidators.get(previous);
	readInvalidators.delete(previous);
	invalidate?.();
}


function imagePortion(
	result: unknown,
	options: { expanded?: boolean },
	theme: { fg: (color: string, text: string) => string },
	context: { toolCallId: string; invalidate: () => void },
	): Container | undefined {
	const content = Array.isArray((result as { content?: unknown })?.content)
		? (result as { content: unknown[] }).content
		: [];
	const images = content.filter(
		(part): part is { type: "image"; data: string; mimeType: string } =>
			part?.type === "image" && typeof part.data === "string" && part.data.length > 0,
		);
	if (images.length === 0) return undefined;

	const stack = new Container();
	if (!(options.expanded === true || context.toolCallId === newestImageReadCallId())) {
		const noun = images.length === 1 ? "image" : "images";
		stack.addChild(
			new Text(`  ${theme.fg("muted", "⎿")}  ${theme.fg("muted", `${images.length} ${noun} — expand to show`)}`, 0, 0),
		);
		return stack;
	}
	readInvalidators.set(context.toolCallId, () => context.invalidate());

	const protocol = detectImageProtocol();
	for (const image of images) {
		if (protocol === null) {
			const dims = getImageDimensions(image.data, image.mimeType);
			const size = dims ? ` ${dims.widthPx}x${dims.heightPx}` : "";
			stack.addChild(new Text(theme.fg("muted", `[Image: ${image.mimeType}${size}]`), 0, 0));
			continue;
		}
		const dims = getImageDimensions(image.data, image.mimeType);
		if (dims) {
			stack.addChild(new Text(theme.fg("muted", `${dims.widthPx}×${dims.heightPx}`), 0, 0));
		}
		stack.addChild(
			new HistoryImageCell({ data: image.data, mimeType: image.mimeType }, (s) => theme.fg("muted", s), {
				autoPrepare: true,
				onPrepared: () => context.invalidate(),
			}),
		);
	}
	return stack;
}

// ── Read tool registration (owns `read`; merged from image-history) ──

// Read definitions are rebuilt per cwd at execute time (path resolution must
// follow the session cwd); the registration itself only carries metadata and
// renderers, neither of which depends on cwd.
const readDefinitions = new Map<string, ReturnType<typeof createReadToolDefinition>>();
function readToolFor(cwd: string): ReturnType<typeof createReadToolDefinition> {
	let definition = readDefinitions.get(cwd);
	if (!definition) {
		definition = createReadToolDefinition(cwd);
		readDefinitions.set(cwd, definition);
	}
	return definition;
}

// NB: must be called at extension LOAD time, never from session_start. pi's
// session-switch flows (in-app /resume, /new, /fork, tree navigation) render
// the restored transcript BEFORE re-binding extensions, so a tool first
// registered in session_start renders its only pass with pi's built-in
// renderer — for SKILL.md reads that's the native `[skill] name` compact row.
// That row also predates the post-bind grouping rescan, never registers a row
// invalidator, and as a batch's first member would permanently swallow the
// batch header ("skill loads break tool grouping on resume").
function registerReadTool(pi: ExtensionAPI): void {
	if (!customUiEnabled()) {
		// Default pi look: boxed row with the built-in fallback text preview
		// (mirrors what tool-execution.ts renders when no renderResult is set).
		pi.registerTool({
			...readToolFor(process.cwd()),
			async execute(toolCallId, params, signal, onUpdate, ctx) {
				return readToolFor(ctx.cwd).execute(toolCallId, params, signal, onUpdate, ctx);
			},
			renderResult(result, options, theme, context) {
				if (!options.isPartial) settleStatus(context, context.isError === true);
				const content = Array.isArray(result?.content) ? result.content : [];
				const text = content
					.filter((part): part is { type: "text"; text: string } =>
						part?.type === "text" && typeof part.text === "string")
					.map((part) => part.text)
					.join("\n");

				const stack = new Container();
				if (text) {
					const lines = text.split("\n");
					const visible = options.expanded ? lines : lines.slice(0, FALLBACK_PREVIEW_LINES);
					let output = visible.map((line) => theme.fg("toolOutput", line)).join("\n");
					const remaining = lines.length - visible.length;
					if (remaining > 0) {
						output += theme.fg("muted", `\n... (${remaining} more lines)`);
					}
					stack.addChild(new Text(output, 0, 0));
				}
				const images = imagePortion(result, options, theme, context);
				if (images) stack.addChild(images);
				return stack;
			},
		});
		return;
	}

	pi.registerTool({
		...readToolFor(process.cwd()),
		renderShell: "self",
		renderCall: readCallSlot,
		async execute(toolCallId, params, signal, onUpdate, ctx) {
			return readToolFor(ctx.cwd).execute(toolCallId, params, signal, onUpdate, ctx);
		},
		renderResult(result, options, theme, context) {
			if (!options.isPartial) settleStatus(context, context.isError === true);
			const mode = groupMode(context.toolCallId);
			const expandedNow = Boolean(options.expanded) || mode.kind === "latest";
			const content = Array.isArray(result?.content) ? result.content : [];
			const images = content.filter(
				(part): part is { type: "image"; data: string; mimeType: string } =>
					part?.type === "image" && typeof part.data === "string" && part.data.length > 0,
				);

			// Grouped rows collapse to a single glance line.
			if ((mode.kind === "collapsed" || mode.kind === "earlier") && !options.expanded) {
				const text = content
					.filter((part): part is { type: "text"; text: string } =>
						part?.type === "text" && typeof part.text === "string")
					.map((part) => part.text)
					.join("\n");
				const bits: string[] = [];
				if (text) bits.push(`${text.split("\n").length} lines`);
				if (images.length > 0) bits.push(`${images.length} image${images.length === 1 ? "" : "s"}`);
				return glanceLine(
					"Read",
					context.args?.path ?? "",
					context.isError === true
						? theme.fg("error", bits.join(" · ") || "failed")
						: theme.fg("dim", bits.join(" · ") || "done"),
					theme,
				);
			}

			// Claude-style one-line call + "N lines" summary, images appended.
			const stack = new Container();
			stack.addChild(
				readTextResult(
					result,
					{ expanded: expandedNow, isPartial: options.isPartial },
					theme,
					latestCap(mode, options.expanded),
				),
			);
			const imagePortionComponent = imagePortion(result, { expanded: expandedNow }, theme, context);
			if (imagePortionComponent) stack.addChild(imagePortionComponent);
			return attachNotes(stack, context, theme);
		},
	});
}

// ── Image features (independent of custom-ui) ─────────────

function registerImageFeatures(pi: ExtensionAPI): void {
	// Inline rendering: replace blob markers in user messages with placeholder
	// rows so the image appears inside the message box. Runs for restored
	// sessions and width changes too, so images survive restarts and resizes.
	pi.registerMarkdownTransformer((markdown, { messageType, isStreaming, availableWidth }) => {
		if (messageType !== "user" || isStreaming) return markdown;
		return transformUserMarkdown(markdown, availableWidth ?? 80);
	});

	pi.registerEntryRenderer("image-history", (entry, _ctx, theme) => {
		const stack = new Container();
		for (const image of ((entry.data as { images?: HistoryImage[] } | undefined)?.images ?? [])) {
			stack.addChild(new HistoryImageCell(image, (s: string) => theme.fg("muted", s)));
		}
		return stack;
	});

	// Fallback for images that never got a blob marker (storeImage unavailable
	// or failed) and images returned by tools (e.g. `read` on an image):
	// persist them as a custom entry rendered below the message.
	pi.on("message_end", async (event, ctx) => {
		const message = (event as { message?: { role?: unknown; content?: unknown } }).message;
		if (!message) return;
		// TUI-only decoration; don't bloat sessions from `pi -p` / JSON mode.
		if (ctx.mode === "print" || ctx.mode === "json") return;
		const found = imagesInMessage(message);
		if (found.length === 0) return;
		if (messageHasBlobMarker(message)) return; // inline transformer handles it
		const images = await Promise.all(found.map(preparedHistoryImage));
		pi.appendEntry("image-history", { images });
	});

	// Live newest-image tracking for collapsed `read` rows (rebuilt from
	// session history on session_start). Without this a read that returned an
	// image never qualifies as the newest image read during the session, so
	// its image stays hidden until the next restart. (Lost in the
	// image-history → custom-ui merge.)
	pi.on("tool_call", async (event) => {
		const e = event as { toolName?: string; toolCallId?: string };
		if (e.toolName !== "read" || typeof e.toolCallId !== "string") return;
		trackReadCall(e.toolCallId);
	});
	pi.on("tool_result", async (event) => {
		const e = event as { toolName?: string; toolCallId?: string; content?: unknown };
		if (e.toolName !== "read" || typeof e.toolCallId !== "string") return;
		const previous = newestImageReadCallId();
		trackReadResult(e.toolCallId, e.content);
		evictPreviouslyNewest(previous, e.toolCallId);
	});
}

// ── User messages: zentui-style "compact" look ────────────────

// Copies the compact user-message style from lmilojevicc/pi-zentui: an
// accent rail (`▎ `) followed by the message body — no box, no background.
// pi offers no hook for restyling built-in message components, so this
// patches UserMessageComponent.prototype.render (fork pattern, guarded by a
// Symbol.for against stacking; any error falls back to the original render).
// The component's own Markdown child is reused rather than re-parsing the
// text, so registered markdown transformers (inline image placeholders) and
// theming keep working, and the OSC-133 prompt-zone markers the original
// render adds around the message are preserved.

const USER_MESSAGE_PATCHED = Symbol.for("pi-custom-ui/userMessageRender");
const OSC_ZONE_START = "\x1b]133;A\x07";
const OSC_ZONE_END = "\x1b]133;B\x07";
const OSC_ZONE_FINAL = "\x1b]133;C\x07";

// Markdown pads lines to equal width in places (e.g. code blocks); the rail
// prefix sits in that padding, so strip it before measuring the line.
function trimMarkdownPadding(line: string): string {
	return line.replace(/ +((?:\x1b\[[0-?]*[ -/]*[@-~])*)$/, "$1");
}

function installCompactUserMessages(getTheme: () => Theme | undefined): void {
	const proto = UserMessageComponent.prototype as unknown as Record<PropertyKey, unknown>;
	if (proto[USER_MESSAGE_PATCHED] || typeof proto.render !== "function") return;
	proto[USER_MESSAGE_PATCHED] = true;
	const originalRender = proto.render as unknown as (this: Container, width: number) => string[];
	proto.render = function (this: Container, width: number) {
		const fallback = () => originalRender.call(this, width);
		try {
			if (typeof width !== "number" || width <= 2) return fallback();
			// children: [Box (padding/bg) → Markdown]
			const markdown = (this as { children?: Array<{ children?: unknown[] }> }).children?.[0]
				?.children?.[0] as { render?: (w: number) => string[] } | undefined;
			if (!markdown || typeof markdown.render !== "function") return fallback();
			const theme = getTheme();
			const rail = `${theme ? theme.fg("accent", "▎") : "▎"} `;
			const railWidth = visibleWidth(rail);
			const body = markdown.render(width - railWidth);
			if (!Array.isArray(body) || body.length === 0) return fallback();
			// Full-width base01 band behind the message (from the stylix
			// palette; see base16Bg in ./lib/custom-ui.ts).
			const bg = base16Bg("base01", "131721");
			const lines = body.map((line) => {
				const content = truncateToWidth(`${rail}${trimMarkdownPadding(line)}`, width, "");
				const pad = " ".repeat(Math.max(0, width - visibleWidth(content)));
				return bg + content + pad + "\x1b[0m";
			});
			lines[0] = OSC_ZONE_START + lines[0];
			lines[lines.length - 1] = OSC_ZONE_END + OSC_ZONE_FINAL + lines[lines.length - 1];
			return lines;
		} catch {
			return fallback();
		}
	};
}

// ── Bash commands (`!`): zentui-style "compact" look ──────────

// Restyles pi's BashExecutionComponent (used for both live `!` runs and
// history rebuilds) to match the compact user-message look: an accent rail
// (base0A yellow, standing out from the blue accent of user messages) on a
// base01 background band — no box. Post-processes the component's own
// render output instead of rebuilding it, so streaming output, the loader,
// truncation status, and ctrl+o expansion all keep working unchanged. The
// box's top/bottom DynamicBorder rows (full-width ─ runs) are dropped.
// While the command runs, the loader row is retargeted too: a random
// cli-spinners dots variant in the rail's yellow, and the "Running…" label
// shimmering through a yellow→orange→red stylix gradient (the fire
// counterpart of the batch header's cyan→purple sweep). Loader internals
// (frames/color fns) are TS-private but plain fields at runtime.
// Note: `!!` (exclude-from-context) commands were previously dim-bordered;
// the exclusion is not observable from render output, so both now render
// identically. Fork pattern, guarded by a Symbol.for against stacking; any
// error falls back to the original render.
const BASH_EXECUTION_PATCHED = Symbol.for("pi-custom-ui/bashExecutionRender");

function installCompactBashCommands(getTheme: () => Theme | undefined): void {
	const proto = BashExecutionComponent.prototype as unknown as Record<PropertyKey, unknown>;
	if (proto[BASH_EXECUTION_PATCHED] || typeof proto.render !== "function") return;
	proto[BASH_EXECUTION_PATCHED] = true;

	// Yellow→orange→red stylix gradient for the bash shimmer — the fire
	// counterpart of the batch header's cyan→purple sweep (base0D→0E→0C).
	const BASH_SHIMMER_STOPS = ["base0A", "base09", "base08"];

	// Loader internals are TS-private but plain fields at runtime. A plain
	// structural view (not an intersection — Loader declares these private,
	// and intersecting private members collapses the type to never).
	type LoaderInternals = {
		frames: string[];
		spinnerColorFn: (s: string) => string;
		messageColorFn: (msg: string) => string;
	};

	// One random dots variant + shimmer cadence per command run (the loader
	// instance is created once in the constructor and survives the
	// contentContainer rebuilds; WeakMap keeps this one-shot).
	const bashLoaderConfigured = new WeakMap<object, true>();
	function configureBashLoader(comp: { contentContainer?: { children?: unknown[] }; status?: string }): void {
		if (comp.status !== "running") return;
		const loader = comp.contentContainer?.children?.find(
			(c): c is LoaderInternals => c instanceof Loader,
		);
		if (!loader || bashLoaderConfigured.has(loader)) return;
		bashLoaderConfigured.set(loader, true);
		// Random dots variant per run — same catalog as the batch header, so
		// the native ⠋⠙⠹ cadence is replaced with the family variety.
		const variant = DOTS_SPINNERS[Math.floor(Math.random() * DOTS_SPINNERS.length)];
		loader.frames = [...(variant ?? DOTS_SPINNERS[0])];
		// Spinner glyph in the rail's yellow (live theme, follows /theme).
		loader.spinnerColorFn = (s) => getTheme()?.fg("warning", s) ?? s;
		// Shimmer the "Running…" label through the yellow/red gradient; the
		// "(esc to cancel)" hint stays muted. The loader's own 80ms tick
		// drives the frame counter — no timer of our own. The shimmer's
		// trailing reset clears the band bg, so re-apply it before the
		// muted hint.
		let frame = 0;
		loader.messageColorFn = (msg) => {
			const cut = msg.indexOf(" (");
			const head = cut === -1 ? msg : msg.slice(0, cut);
			const tail = cut === -1 ? "" : msg.slice(cut);
			const theme = getTheme();
			return (
				shimmerFrame(head, frame++, BASH_SHIMMER_STOPS) +
				(tail ? base16Bg("base01", "131721") + (theme ? theme.fg("muted", tail) : tail) : "")
			);
		};
	}

	const originalRender = proto.render as unknown as (this: Container, width: number) => string[];
	proto.render = function (this: Container, width: number) {
		const fallback = () => originalRender.call(this, width);
		try {
			if (typeof width !== "number" || width <= 2) return fallback();
			// Retarget the loader before the first render so the spinner and
			// shimmer take over immediately (the first frame may still show
			// the native one; the loader's next 80ms tick self-corrects).
			configureBashLoader(this as unknown as { contentContainer?: { children?: unknown[] }; status?: string });
			const rendered = fallback();
			if (!Array.isArray(rendered) || rendered.length === 0) return rendered;
			const theme = getTheme();
			// Yellow rail: under the stylix-generated theme (pi/default.nix)
			// `warning` maps to base0A, the scheme's yellow — kept distinct from
			// the blue accent rail of user messages. Follows /theme switches.
			const rail = `${theme ? theme.fg("warning", "▎") : "▎"} `;
			const bg = base16Bg("base01", "131721");
			const isBlank = (line: string) =>
				line.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").trim() === "";
			// Spacing normalization: command output ending in \n leaves a blank
			// line in outputLines, which stacks with the loader's/status row's
			// own leading blank into a double gap. Collapse blank runs to one,
			// then ensure exactly one trailing blank — the spinner/status row
			// ends up with one blank line before and after.
			const rows: string[] = [];
			for (const line of rendered) {
				// DynamicBorder rows render as exactly `width` ─ glyphs
				// (SGR-colored); command output lines never match both
				// conditions, so this drops the box without touching output.
				const plain = line.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
				if (plain.length === width && /^─+$/.test(plain)) continue;
				if (isBlank(line) && rows.length > 0 && isBlank(rows[rows.length - 1])) continue;
				rows.push(line);
			}
			if (rows.length > 0 && !isBlank(rows[rows.length - 1])) rows.push("");
			return rows.map((line) => {
				// Text children render with paddingX = 1; the rail provides
				// the indent, so drop the leading pad space.
				const body = line.replace(/^ /, "");
				const content = truncateToWidth(`${rail}${body}`, width, "");
				const pad = " ".repeat(Math.max(0, width - visibleWidth(content)));
				return bg + content + pad + "\x1b[0m";
			});
		} catch {
			return fallback();
		}
	};
}

export default function customUi(pi: ExtensionAPI) {
	// Image features (inline user-message images, history fallback cells)
	// register regardless of the custom-ui setting — they're a rendering
	// fix, not a style choice. Only the tool rendering below is gated.
	registerImageFeatures(pi);

	// Owns `read` (merged from image-history). Load-time registration is
	// load-bearing: see the NB on registerReadTool. Must run before the
	// customUiEnabled gate — the disabled branch still registers read (with
	// the built-in look plus tool-result image rendering).
	registerReadTool(pi);

	// ctrl+o (tool output expansion) prints a "Tool output: expanded/collapsed"
	// status row straight into the chat scrollback; landing between grouped
	// tool rows it visually splits the batch. Drop just that message — every
	// other showStatus ("Forked to new session", …) stays. Rendering fix, not
	// a style choice, so it applies regardless of the custom-ui setting.
	const STATUS_PATCHED = Symbol.for("pi-custom-ui/showStatus");
	const statusProto = InteractiveMode.prototype as unknown as Record<PropertyKey, unknown>;
	if (typeof statusProto.showStatus === "function" && !statusProto[STATUS_PATCHED]) {
		statusProto[STATUS_PATCHED] = true;
		const originalShowStatus = statusProto.showStatus as (
			this: InteractiveMode,
			message: string,
		) => void;
		statusProto.showStatus = function (this: InteractiveMode, message: string) {
			if (/^Tool output: (expanded|collapsed)$/.test(message)) return;
			originalShowStatus.call(this, message);
		};
	}

	// With the style disabled nothing further happens here: pi's built-ins
	// stay as they are (read was registered below; bash stays with nix-comma).
	if (!customUiEnabled()) return;

	// User messages get the zentui compact look (rail + body, no box). The
	// theme handle reads ctx.ui.theme lazily at render time — it's a live
	// getter over the module-level theme, so /theme switches are tracked.
	let userMessageUi: { theme?: Theme } | undefined;
	installCompactUserMessages(() => userMessageUi?.theme);
	// `!` shell commands get the same treatment (yellow rail instead of the
	// blue user-message rail, same base01 band).
	installCompactBashCommands(() => userMessageUi?.theme);


	// Systemic notify routing: any extension's ctx.ui.notify (info level) is
	// folded into the open batch as a note line under its latest tool row
	// instead of rendering a raw chat row that interleaves with the glance
	// lines. Warnings/errors and notifications outside a batch stay native.
	// Patched once at the prototype (fork-style), guarded against stacking.
	const NOTIFY_PATCHED = Symbol.for("pi-custom-ui/showExtensionNotify");
	const notifyProto = InteractiveMode.prototype as unknown as Record<PropertyKey, unknown>;
	if (typeof notifyProto.showExtensionNotify === "function" && !notifyProto[NOTIFY_PATCHED]) {
		notifyProto[NOTIFY_PATCHED] = true;
		const originalNotify = notifyProto.showExtensionNotify as (
			this: InteractiveMode,
			message: string,
			type?: string,
		) => void;
		notifyProto.showExtensionNotify = function (message: string, type?: string) {
			if ((type ?? "info") === "info" && pushToolNote(message)) return;
			originalNotify.call(this, message, type);
		};
	}

	// ── Turn summary (zentui-faithful, MIT) ───────────────
	// One settled row per agent run, appended at agent_end and persisted via
	// appendEntry + entry renderer (renders identically on restore):
	//   Turn took 1m 51s · thought for 1m 39s · ↑12.4k ↓830
	// Duration is agent-run wall clock; tokens are provider-reported usage
	// summed per assistant message at message_end; thought time is summed
	// from the fork's published per-message thinking timings at settle.
	const TURN_SUMMARY_TYPE = "turn-summary";
	let turnStartedAt = 0;
	let turnSpinnerSeed = 0;
	const turnTimestamps = new Set<number>();
	const turnTokens = { input: 0, output: 0 };

	const formatTurnDuration = (ms: number): string => {
		const total = Math.max(0, Math.floor(ms / 1000));
		const h = Math.floor(total / 3600);
		const m = Math.floor((total % 3600) / 60);
		const s = total % 60;
		if (h > 0) return `${h}h ${m}m`;
		if (m > 0) return `${m}m ${s}s`;
		return `${s}s`;
	};
	const formatTokCount = (v: number): string => {
		if (v < 1000) return String(v);
		if (v < 10_000) return `${(v / 1000).toFixed(1)}k`;
		if (v < 1_000_000) return `${Math.round(v / 1000)}k`;
		if (v < 10_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
		return `${Math.round(v / 1_000_000)}M`;
	};
	// Styling per user spec: the whole row bold base03 (an earlier per-piece
	// variant — base02 dots, yellow/grey arrows — read poorly and was
	// dropped). Raw base16 SGR; base16Fg falls back when the palette is absent.
	const formatTurnSummaryText = (data: { durationMs: number; thoughtMs: number; input: number; output: number }): string => {
		const base03 = base16Fg("base03", "6a737d");
		const parts = [`Turn took ${formatTurnDuration(data.durationMs)}`];
		if (data.thoughtMs >= 1000) parts.push(`thought for ${formatTurnDuration(data.thoughtMs)}`);
		parts.push(`↑${formatTokCount(data.input)} ↓${formatTokCount(data.output)}`);
		return ` ${base03}\x1b[1m${parts.join(" · ")}\x1b[22m\x1b[39m`;
	};

	pi.registerEntryRenderer(TURN_SUMMARY_TYPE, (entry, _options, _theme) => {
		const data = entry.data as
			| { durationMs?: number; thoughtMs?: number; input?: number; output?: number }
			| undefined;
		if (!data) return new Text("", 0, 0);
		return new Text(formatTurnSummaryText({
			durationMs: data.durationMs ?? 0,
			thoughtMs: data.thoughtMs ?? 0,
			input: data.input ?? 0,
			output: data.output ?? 0,
		}), 0, 0);
	});

	// Tool call grouping: consecutive tool calls form a batch while nothing
	// visible separates them — visible assistant text, a user message, or the
	// end of the agent's response splits the batch; thinking runs fold into
	// it visually (their durations surface in the batch header) without
	// closing it. Bare tool-carrier messages (e.g. a silent retry after a
	// failed call) join the current batch instead of starting a new one.
	// Each collapsed batch gets a settled header with an nf check glyph. State lives in
	// the shared lib module.
	// A tool call stamps its batch with the timestamp of the assistant message
	// that contains it, so the header can look up that message's thinking
	// duration (published by the pi-thinking-fold fork). The mapping is built
	// from streaming partials — the tool_call event fires after message_end,
	// so per-message flags would be unreliable. Thinking runs fold into the
	// batch; only visible assistant text, a user message, or the end of the
	// response splits it.
	const toolCallThoughtKey = new Map<string, number>();

	function hasVisibleText(message: any): boolean {
		return Array.isArray(message?.content) &&
			message.content.some(
				(part: any) =>
					part !== null && typeof part === "object" &&
					part.type === "text" && typeof part.text === "string" &&
					part.text.trim().length > 0,
			);
	}

	// While the batch header is visible (any thinking streams over it, or ≥2
	// tool calls are in), the lib animates the header — dots spinner + shimmer
	// verb + live durations. The tick bumps the animation clock and re-renders
	// the batch; when there is nothing to animate it returns false and the
	// timer stops until the next tool_call/thinking_delta restarts it. Kept
	// alive through thinking_end so tools that follow still animate.
	const LIVE_THOUGHT_KEY = "__piCustomUiLiveThought";
	let tickTimer: ReturnType<typeof setInterval> | undefined;
	const stopThoughtTick = () => {
		if (tickTimer) clearInterval(tickTimer);
		tickTimer = undefined;
	};
	const ensureTick = () => {
		if (!tickTimer) {
			// 80ms — the cli-spinners dots family's default interval.
			tickTimer = setInterval(() => {
				if (!tickOpenBatch()) stopThoughtTick();
			}, 80);
		}
	};
	const setLiveThought = (ts: number | undefined) => {
		(globalThis as Record<string, unknown>)[LIVE_THOUGHT_KEY] = ts;
	};

	// Unification rule: exactly one activity indicator at a time. With
	// custom-ui owning tool rendering, the native loader row (braille spinner
	// + generic "Working..."/"Thinking...") NEVER shows — it carries no
	// information the transcript doesn't (live header, glance rows, tool
	// dots), and the animated transcript row is the sole indicator. The flag
	// is set false once at session_start and re-asserted at agent_start (pi
	// respects workingVisible there: it clears instead of showing) and on
	// thinking_delta. Retry/compaction indicators are separate kinds and
	// unaffected. Nothing sets it back to true: showing it again at agent_end
	// would flash "Working..." at the start of the next turn.
	type LoaderCtx = { mode?: string; ui?: { setWorkingVisible?: (visible: boolean) => void } } | undefined;
	const setLoaderVisible = (ctx: LoaderCtx, visible: boolean) => {
		if (ctx?.mode !== "tui") return;
		try {
			ctx.ui?.setWorkingVisible?.(visible);
		} catch {
			// Older pi builds without the API — indicator stays as pi drew it.
		}
	};

	// ── Dead-air loader ─────────────
	// The native loader stays hidden while anything is visibly happening —
	// streaming deltas, an open batch header, an in-flight tool dot all
	// count as activity — but mid-turn latency with zero events and zero
	// spinners makes the turn look dead. A low-frequency check re-shows the
	// loader after 500ms of event silence (only when no batch/tool spinner
	// is active) and hides it the moment activity resumes.
	let lastAgentEventAt = 0;
	let inFlightTools = 0;
	let loaderTimer: ReturnType<typeof setInterval> | undefined;
	const noteAgentActivity = () => {
		lastAgentEventAt = Date.now();
	};

	pi.on("tool_call", async (event, ctx) => {
		noteAgentActivity();
		inFlightTools += 1;
		const e = event as { toolCallId?: string };
		if (typeof e.toolCallId === "string") {
			trackGroupToolCall(e.toolCallId, toolCallThoughtKey.get(e.toolCallId));
			ensureTick();
		}
	});
	pi.on("tool_result", async () => {
		noteAgentActivity();
		inFlightTools = Math.max(0, inFlightTools - 1);
	});
	pi.on("agent_start", async (_event, ctx) => {
		noteAgentActivity();
		setLoaderVisible(ctx, false);
		// The dead-air loader is OUR animated label (dots glyph + shimmer verb,
		// written per-tick below) — pi's native indicator is hidden entirely so
		// the row shows exactly one spinner.
		turnSpinnerSeed = Date.now();
		if (ctx.mode === "tui") {
			try {
				(ctx as { ui?: { setWorkingIndicator?: (o?: unknown) => void } }).ui?.setWorkingIndicator?.({
					frames: [],
				});
			} catch {
				// Older builds without the API — native indicator stays.
			}
		}
		turnStartedAt = Date.now();
		turnTimestamps.clear();
		turnTokens.input = 0;
		turnTokens.output = 0;
		if (ctx.mode !== "tui") return;
		loaderTimer?.unref?.();
		clearInterval(loaderTimer);
		const c = ctx;
		loaderTimer = setInterval(() => {
			// Dead-air loader for the two states with no other spinner:
			// - no batch yet (turn-start provider latency, before the first
			//   thinking fold row appears)
			// - a SOLO batch (one tool call, no animated header) — dead air
			//   after its tool would otherwise show nothing
			// Bigger batches have the animated header; fresh thinking has the
			// animated fold row; in-flight tools have the dotsCircle dot.
			const jobs = currentBatchSize();
			const idle =
				Date.now() - lastAgentEventAt > 500 && inFlightTools === 0 && (jobs === undefined || jobs === 1);
			setLoaderVisible(c, idle);
			if (c.mode !== "tui") return;
			try {
				(c as { ui?: { setWorkingMessage?: (m?: string) => void } }).ui?.setWorkingMessage?.(
					idle ? animState().loaderLabel(turnSpinnerSeed) : undefined,
				);
			} catch { /* debug-tolerant */ }
		}, 80);
	});
	pi.on("message_start", async (event) => {
		noteAgentActivity();
		const message = (event as { message?: { role?: unknown } }).message;
		if (message?.role === "user") {
			stopThoughtTick();
			setLiveThought(undefined);
			collapseToolGroup();
		}
	});
	pi.on("message_update", async (event, ctx) => {
		noteAgentActivity();
		const e = event as { assistantMessageEvent?: { type?: unknown }; message?: any };
		const type = e.assistantMessageEvent?.type;
		// Collapse as soon as visible text streams (whitespace-only text blocks
		// must not split batches). Idempotent: once the current batch is
		// collapsed, later deltas are no-ops.
		if (type === "thinking_delta") {
			foldToolGroup();
			setLiveThought(typeof e.message?.timestamp === "number" ? e.message.timestamp : undefined);
			ensureTick();
			setLoaderVisible(ctx, false);
		}
		if (type === "thinking_end") {
			// Duration is complete; the timer keeps running so the header
			// spinner/shimmer stays alive while tools of this batch stream.
			setLiveThought(undefined);
		}
		if (type === "text_delta" && hasVisibleText(e.message)) {
			// Visible text splits the batch — narration separates tool
			// groups; reasoning-only fold (see thinking_delta above).
			collapseToolGroup();
			stopThoughtTick();
			setLiveThought(undefined);
		}
		// Stamp every tool call of a thinking message with its timestamp.
		// Runs on every update (not just thinking_delta): thinking streams
		// before the toolCall blocks exist, so the ids only become mappable
		// once both are present in the partial content.
		// Narrated messages (thinking → text → toolCall) are exempt: their
		// fold row stays visible (fork narration exemption) and shows the
		// duration; stamping would make the next batch header count the same
		// thinking twice.
		if (
			typeof e.message?.timestamp === "number" &&
			Array.isArray(e.message?.content) &&
			e.message.content.some((part: any) => part?.type === "thinking") &&
			!hasVisibleText(e.message)
		) {
			for (const part of e.message.content) {
				if (part?.type === "toolCall" && typeof part.id === "string") {
					toolCallThoughtKey.set(part.id, e.message.timestamp);
				}
			}
		}
	});
	// Per-assistant-message bookkeeping for the turn summary: timestamps (to
	// look up the fork's published thinking timings at settle) and
	// provider-reported usage.
	pi.on("message_end", async (event) => {
		noteAgentActivity();
		const message = (event as { message?: { role?: unknown; timestamp?: number; usage?: { input?: number; output?: number } } }).message;
		if (message?.role !== "assistant") return;
		if (typeof message.timestamp === "number") turnTimestamps.add(message.timestamp);
		turnTokens.input += message.usage?.input ?? 0;
		turnTokens.output += message.usage?.output ?? 0;
	});

	// NB: turn_end fires per assistant *message* (with its tool results), so
	// collapsing there would split sequential tool calls into solo batches.
	// agent_end fires once when the whole response settles.
	pi.on("agent_end", async (_event, ctx) => {
		noteAgentActivity();
		stopThoughtTick();
		setLiveThought(undefined);
		collapseToolGroup();
		clearInterval(loaderTimer);
		loaderTimer = undefined;
		setLoaderVisible(ctx, false);
		if (ctx?.mode !== "tui" || !turnStartedAt || turnTimestamps.size === 0) return;
		// Thinking wall-clock: the fork publishes per-message timings
		// (completed) plus in-progress entries; sum over this turn's messages.
		const w = globalThis as Record<string, unknown>;
		const done = w.__piCustomUiThoughtFor as Map<number, number> | undefined;
		const live = w.__piCustomUiThoughtLive as
			| Map<number, { startedAt: number; completedAt?: number }>
			| undefined;
		let thoughtMs = 0;
		for (const ts of turnTimestamps) {
			const d = done?.get(ts);
			if (typeof d === "number") {
				thoughtMs += d;
				continue;
			}
			const lt = live?.get(ts);
			if (lt) thoughtMs += Math.max(0, (lt.completedAt ?? Date.now()) - lt.startedAt);
		}
		pi.appendEntry(TURN_SUMMARY_TYPE, {
			v: 1,
			durationMs: Date.now() - turnStartedAt,
			thoughtMs,
			input: turnTokens.input,
			output: turnTokens.output,
		});
		turnStartedAt = 0;
	});
	pi.on("session_start", async (_event, ctx) => {
		stopThoughtTick();
		setLiveThought(undefined);
		toolCallThoughtKey.clear();
		clearInterval(loaderTimer);
		loaderTimer = undefined;
		userMessageUi = ctx.ui as { theme?: Theme };
		setLoaderVisible(ctx, false);
		if (ctx.mode === "print" || ctx.mode === "json") return;
		// Capture the TUI so animation ticks can force repaints — the zero-line
		// widget capture trick (same as thinking-fold-redraw.ts; the UI context
		// exposes no requestRender). Published on the shared anim API so the
		// pi-thinking-fold timer can drive its streaming label with it too.
		ctx.ui.setWidget("custom-ui-anim", (t) => {
			animState().requestRender = () => t.requestRender();
			return { render: () => [], invalidate() {}, dispose() { animState().requestRender = undefined; } };
		});
		scanToolGroupsFromHistory(
			ctx.sessionManager.getEntries() as Array<{ type: string; message?: unknown }>,
		);
		// Rebuild the newest-image-read pointer. (`read` itself is registered
		// at load time with per-cwd execute — see registerReadTool — so no
		// re-registration is needed on session switches.)
		scanHistoryForReadTracking(
			ctx.sessionManager.getEntries() as Array<{ type: string; message?: unknown }>,
		);
		readInvalidators.clear();
	});

	// Original tools are recreated per cwd at execute time (cached); the
	// registration itself only borrows description/parameters/prompt metadata
	// from the cwd at load time.
	const cache = new Map<string, Record<string, ReturnType<typeof createEditTool>>>();
	function builtins(cwd: string) {
		let tools = cache.get(cwd);
		if (!tools) {
			tools = {
				edit: createEditTool(cwd),
				write: createWriteTool(cwd),
				grep: createGrepTool(cwd),
				find: createFindTool(cwd),
				ls: createLsTool(cwd),
			};
			cache.set(cwd, tools);
		}
		return tools;
	}

	const slots = { edit, write, grep, find, ls } as const;
	for (const name of Object.keys(slots) as Array<keyof typeof slots>) {
		const original = builtins(process.cwd())[name]!;
		const slot = slots[name];
		pi.registerTool({
			...original,
			renderShell: slot.renderShell,
			renderCall: slot.renderCall,
			renderResult: slot.renderResult,
			async execute(toolCallId, params, signal, onUpdate, ctx) {
				return builtins(ctx.cwd)[name]!.execute(toolCallId, params, signal, onUpdate);
			},
		});
	}

	// `bash` ownership: this extension loads before nix-comma, so its
	// registration wins. The PATH spawn hook from nix-comma is consulted
	// through its published handle (globalThis.__nixCommaSpawnHook); with
	// nix-comma absent this is plain bash with custom-ui rendering.
	pi.registerTool({
		...createBashToolDefinition(process.cwd(), {
			spawnHook: ({ command, cwd, env }) => {
				const hook = (globalThis as Record<string, unknown>).__nixCommaSpawnHook as
					| ((h: { command: string; cwd: string; env: Record<string, string | undefined> }) =>
							| { command: string; cwd: string; env: Record<string, string | undefined> }
							| undefined)
					| undefined;
				const patched = hook?.({ command, cwd, env });
				return { command, cwd, env: { ...env, ...(patched?.env ?? {}) } };
			},
		}),
		renderShell: bash.renderShell,
		renderCall: bash.renderCall,
		renderResult: bash.renderResult,
	});

	// Opt-in API for third-party tools (see header comment). maybeDecorate
	// returns a custom-ui-rendered copy of the caller's tool definition —
	// the caller registers the returned value. Without this extension loaded
	// (or with the style off) callers register their plain tool unchanged:
	// they either consult this API or don't, their choice.
	const STYLE_API_KEY = "__piCustomUi";
	const api = {
		version: 1 as const,
		maybeDecorate<T extends Record<string, unknown>>(
			tool: T,
			opts?: { label?: string; argOf?: (args: any) => string },
		): T {
			const slotSet = genericSlots(
				opts?.label ?? String(tool?.name ?? "Tool"),
				opts?.argOf ?? (() => ""),
			);
			return { ...tool, renderShell: slotSet.renderShell, renderCall: slotSet.renderCall, renderResult: slotSet.renderResult };
		},
	};
	(globalThis as Record<string, unknown>)[STYLE_API_KEY] = api;

}
