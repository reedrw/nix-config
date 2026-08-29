// Shows submitted images inline in the chat history via the Kitty graphics
// protocol. pi-image-view renders previews above the editor while composing,
// but collapses them on submit. This extension renders each user message's
// image attachments inside the message itself, by replacing pi-image-view's
// `[[Image #N]](file://…/image-view/blobs/…)` markdown markers with kitty
// placeholder rows through a markdown transformer. Because the rows are part
// of the message text, the image sits inside the message box and stays there
// in the live view, in scrollback, and across restarts (blobs are read from
// pi-image-view's persistent store, so nothing extra goes in the session).
//
// Uses kitty's Unicode placeholder protocol (U+10EEEE cells + diacritics)
// rather than pi-tui's built-in Image component: pi-tui hard-disables images
// under tmux, while placeholders are ordinary text cells that tmux manages
// per-pane. Placements are never deleted — the image must stay alive once its
// lines scroll into history. Image IDs are content-hashed so re-renders
// replace data in place instead of leaking.
//
// Messages with image blocks but no blob markers (e.g. storeImage failed) fall
// back to a custom session entry rendered below the message.
//
// Images returned by tools are rendered INSIDE the tool result's box: the
// extension overrides the built-in `read` tool's `renderResult` slot to emit a
// Container with the text output plus a HistoryImageCell per image block.
// (pi's built-in tool image rendering uses pi-tui's Image component, which is
// hard-disabled under tmux, and always draws outside the box anyway — so it is
// turned off via terminal.showImages=false and replaced by this.)
//
// Inline images must be PNG (kitty's f=100 transmission requires PNG);
// blob-store previews always are. Full-resolution non-PNG attachments never
// reach the transcript — the model payload isn't persisted by this extension.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { convertToPng, createReadToolDefinition, resizeImage } from "@earendil-works/pi-coding-agent";
import {
	calculateImageRows,
	Container,
	getCapabilities,
	getCellDimensions,
	getImageDimensions,
	type Component,
	ImageProtocol,
	Text,
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

export default function imageHistoryExtension(pi: import("@earendil-works/pi-coding-agent").ExtensionAPI) {
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
			stack.addChild(new HistoryImageCell(image, (s: string) => theme.fg("dim", s)));
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

	// Tool result images (e.g. `read` on an image) are rendered inside the tool
	// result's box via a `read` renderResult override. Spreading the built-in
	// definition keeps its execute/renderCall/prompt metadata; only the result
	// slot changes. Re-registered on session_start to pick up the session cwd.
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode === "print" || ctx.mode === "json") return;
		const readDefinition = createReadToolDefinition(ctx.cwd);
		pi.registerTool({
			...readDefinition,
			renderResult(result, options, theme, context) {
				const content = Array.isArray(result?.content) ? result.content : [];
				const text = content
					.filter((part): part is { type: "text"; text: string } =>
						part?.type === "text" && typeof part.text === "string")
					.map((part) => part.text)
					.join("\n");
				const images = content.filter(
					(part): part is { type: "image"; data: string; mimeType: string } =>
						part?.type === "image" && typeof part.data === "string" && part.data.length > 0,
					);

				const stack = new Container();
				if (text) {
					// Mirror the built-in fallback's collapsed preview behavior.
					const lines = text.split("\n");
					const visible = options.expanded ? lines : lines.slice(0, FALLBACK_PREVIEW_LINES);
					let output = visible.map((line) => theme.fg("toolOutput", line)).join("\n");
					const remaining = lines.length - visible.length;
					if (remaining > 0) {
						output += theme.fg("muted", `\n... (${remaining} more lines)`);
					}
					stack.addChild(new Text(output, 0, 0));
				}
				const protocol = detectImageProtocol();
				for (const image of images) {
					if (protocol === null) {
						const dims = getImageDimensions(image.data, image.mimeType);
						const size = dims ? ` ${dims.widthPx}x${dims.heightPx}` : "";
						stack.addChild(new Text(theme.fg("dim", `[Image: ${image.mimeType}${size}]`), 0, 0));
						continue;
					}
					const dims = getImageDimensions(image.data, image.mimeType);
					if (dims) {
						stack.addChild(new Text(theme.fg("dim", `${dims.widthPx}×${dims.heightPx}`), 0, 0));
					}
					stack.addChild(
						new HistoryImageCell({ data: image.data, mimeType: image.mimeType }, (s) => theme.fg("dim", s), {
							autoPrepare: true,
							onPrepared: () => context.invalidate(),
						}),
					);
				}
				return stack;
			},
		});
	});
}
