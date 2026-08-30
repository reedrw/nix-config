// claude-style-ui: Claude Code inspired rendering for pi's built-in tools,
// owned here outright (pi gives tool-name ownership to the first extension
// that registers; this extension loads before nix-comma, so it wins `bash`).
//
// One-line calls (`● edit src/foo.ts`), one-line result summaries
// (`⎿  +12 −3`, `⎿  42 lines`), no boxes — full output on demand via
// ctrl+o. Render slots live in lib/claude-style.ts.
//
// Also owns the `read` tool with inline kitty-placeholder image rendering
// (merged from image-history.ts): user-message images, history fallback
// cells, and tool-result images inside the read row.
//
// Other extensions opt in voluntarily via the __piClaudeStyle runtime API
// (no lib import, no load-order coupling):
//   const api = (globalThis as any).__piClaudeStyle;
//   pi.registerTool(api?.maybeDecorate(myTool, { label: "My Tool", argOf: (a) => a.path }) ?? myTool);
// Registration order: the API installs when this extension loads, which is
// before user extensions (alphabetical in ~/.pi/agent/extensions), so the
// simple `api?.maybeDecorate(...) ?? myTool` form is always safe here.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
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
	claudeStyleEnabled,
	edit,
	base16Bg,
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
	settleStatus,
	tickFoldedBatch,
	trackGroupToolCall,
	write,
} from "./lib/claude-style.ts";
import {
	calculateImageRows,
	Container,
	getCapabilities,
	getCellDimensions,
	getImageDimensions,
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

function registerReadTool(pi: ExtensionAPI, cwd: string): void {
	const readDefinition = createReadToolDefinition(cwd);
	if (!claudeStyleEnabled()) {
		// Default pi look: boxed row with the built-in fallback text preview
		// (mirrors what tool-execution.ts renders when no renderResult is set).
		pi.registerTool({
			...readDefinition,
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
		...readDefinition,
		renderShell: "self",
		renderCall: readCallSlot,
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

// ── Image features (independent of claude-style) ─────────────

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
	// image-history → claude-style-ui merge.)
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

const USER_MESSAGE_PATCHED = Symbol.for("pi-claude-style/userMessageRender");
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
			// palette; see base16Bg in ./lib/claude-style.ts).
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

export default function claudeStyleUi(pi: ExtensionAPI) {
	// Image features (inline user-message images, history fallback cells)
	// register regardless of the claude-style setting — they're a rendering
	// fix, not a style choice. Only the tool rendering below is gated.
	registerImageFeatures(pi);
	// With the style disabled nothing further happens here: pi's built-ins
	// stay as they are (read was registered below; bash stays with nix-comma).
	if (!claudeStyleEnabled()) return;

	// User messages get the zentui compact look (rail + body, no box). The
	// theme handle reads ctx.ui.theme lazily at render time — it's a live
	// getter over the module-level theme, so /theme switches are tracked.
	let userMessageUi: { theme?: Theme } | undefined;
	installCompactUserMessages(() => userMessageUi?.theme);


	// Systemic notify routing: any extension's ctx.ui.notify (info level) is
	// folded into the open batch as a note line under its latest tool row
	// instead of rendering a raw chat row that interleaves with the glance
	// lines. Warnings/errors and notifications outside a batch stay native.
	// Patched once at the prototype (fork-style), guarded against stacking.
	const NOTIFY_PATCHED = Symbol.for("pi-claude-style/showExtensionNotify");
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

	// Tool call grouping: consecutive tool calls form a batch while nothing
	// visible separates them — visible assistant text, a user message, or the
	// end of the agent's response splits the batch; thinking runs fold into
	// it visually (their durations surface in the batch header) without
	// closing it. Bare tool-carrier messages (e.g. a silent retry after a
	// failed call) join the current batch instead of starting a new one.
	// Each collapsed batch gets a `✻ Ran N tool calls` header. State lives in
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

	// While reasoning streams over a folded batch, the lib computes the
	// header duration live (completed blocks + the in-progress block's
	// elapsed time); a timer re-renders the batch so it counts up. The key of
	// the streaming message is published for the lib and cleared whenever the
	// reasoning phase ends.
	const LIVE_THOUGHT_KEY = "__piClaudeStyleLiveThought";
	let tickTimer: ReturnType<typeof setInterval> | undefined;
	const stopThoughtTick = () => {
		if (tickTimer) clearInterval(tickTimer);
		tickTimer = undefined;
	};
	const setLiveThought = (ts: number | undefined) => {
		(globalThis as Record<string, unknown>)[LIVE_THOUGHT_KEY] = ts;
	};

	pi.on("tool_call", async (event) => {
		const e = event as { toolCallId?: string };
		if (typeof e.toolCallId === "string") {
			trackGroupToolCall(e.toolCallId, toolCallThoughtKey.get(e.toolCallId));
		}
	});
	pi.on("message_start", async (event) => {
		const message = (event as { message?: { role?: unknown } }).message;
		if (message?.role === "user") {
			stopThoughtTick();
			setLiveThought(undefined);
			collapseToolGroup();
		}
	});
	pi.on("message_update", async (event) => {
		const e = event as { assistantMessageEvent?: { type?: unknown }; message?: any };
		const type = e.assistantMessageEvent?.type;
		// Collapse as soon as visible text streams (whitespace-only text blocks
		// must not split batches). Idempotent: once the current batch is
		// collapsed, later deltas are no-ops.
		if (type === "thinking_delta") {
			foldToolGroup();
			setLiveThought(typeof e.message?.timestamp === "number" ? e.message.timestamp : undefined);
			if (!tickTimer) {
				// Once per second, matching thinking-fold's own item timer.
				tickTimer = setInterval(() => {
					if (!tickFoldedBatch()) stopThoughtTick();
				}, 1000);
			}
		}
		if (type === "thinking_end") {
			// Duration is complete — one final render, then stop counting.
			tickFoldedBatch();
			stopThoughtTick();
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
		if (
			typeof e.message?.timestamp === "number" &&
			Array.isArray(e.message?.content) &&
			e.message.content.some((part: any) => part?.type === "thinking")
		) {
			for (const part of e.message.content) {
				if (part?.type === "toolCall" && typeof part.id === "string") {
					toolCallThoughtKey.set(part.id, e.message.timestamp);
				}
			}
		}
	});
	// NB: turn_end fires per assistant *message* (with its tool results), so
	// collapsing there would split sequential tool calls into solo batches.
	// agent_end fires once when the whole response settles.
	pi.on("agent_end", async () => {
		stopThoughtTick();
		setLiveThought(undefined);
		collapseToolGroup();
	});
	pi.on("session_start", async (_event, ctx) => {
		stopThoughtTick();
		setLiveThought(undefined);
		toolCallThoughtKey.clear();
		userMessageUi = ctx.ui as { theme?: Theme };
		if (ctx.mode === "print" || ctx.mode === "json") return;
		scanToolGroupsFromHistory(
			ctx.sessionManager.getEntries() as Array<{ type: string; message?: unknown }>,
		);
		// Rebuild the newest-image-read pointer and (re)register `read` for the
		// session cwd — re-registration updates the definition's cwd on switch.
		scanHistoryForReadTracking(
			ctx.sessionManager.getEntries() as Array<{ type: string; message?: unknown }>,
		);
		readInvalidators.clear();
		registerReadTool(pi, ctx.cwd);
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
	// nix-comma absent this is plain bash with claude-style rendering.
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
	// returns a claude-style-rendered copy of the caller's tool definition —
	// the caller registers the returned value. Without this extension loaded
	// (or with the style off) callers register their plain tool unchanged:
	// they either consult this API or don't, their choice.
	const STYLE_API_KEY = "__piClaudeStyle";
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
