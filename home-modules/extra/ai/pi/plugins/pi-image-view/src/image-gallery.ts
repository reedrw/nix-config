import {
	type Component,
	getCapabilities,
	type ImageProtocol,
	getImageDimensions,
	calculateImageRows,
	getCellDimensions,
} from "@earendil-works/pi-tui";

/**
 * Detect image protocol support, working around pi-tui ≥0.67.6 which
 * hardcodes `images: null` inside tmux/screen for safety. Our extension
 * uses the Unicode placeholder protocol which is specifically designed
 * to work inside tmux, so we can safely detect kitty-in-tmux ourselves.
 */
function detectImageProtocol(): ImageProtocol | null {
	const caps = getCapabilities();
	if (caps.images) return caps.images;

	// pi-tui returns null inside tmux — check if the outer terminal is kitty
	const inTmux = !!process.env.TMUX || (process.env.TERM?.toLowerCase() || "").startsWith("tmux");
	if (inTmux) {
		if (process.env.KITTY_WINDOW_ID || (process.env.TERM_PROGRAM?.toLowerCase() || "") === "kitty") {
			return "kitty";
		}
		// ghostty and wezterm also support kitty graphics in tmux
		const termProgram = process.env.TERM_PROGRAM?.toLowerCase() || "";
		if (termProgram === "ghostty" || process.env.GHOSTTY_RESOURCES_DIR) return "kitty";
		if (termProgram === "wezterm" || process.env.WEZTERM_PANE) return "kitty";
	}

	return null;
}

export interface GalleryTheme {
	accent: (s: string) => string;
	muted: (s: string) => string;
	dim: (s: string) => string;
	bold: (s: string) => string;
}

export interface GalleryImage {
	data: string; // base64
	mimeType: string;
	label: string;
}

const THUMB_MAX_WIDTH = 25;
const THUMB_MAX_ROWS = 15; // cap height so tall images don't overflow the terminal
const GAP = 2; // columns between images

// Monotonic counter for kitty image IDs — avoids birthday-paradox collisions
// that occurred with the previous Math.random() * 254 approach.
// Uses the full 24-bit range (1–16,777,215) supported by kitty's true-color encoding.
let nextImageId = 1;
function allocateImageId(): number {
	const id = nextImageId;
	nextImageId = (nextImageId % 0xffffff) + 1; // wrap at 16M, skip 0
	return id;
}

// ── Kitty Unicode Placeholder Protocol ─────────────────────
// Instead of rendering pixels directly (which ghost across tmux panes),
// we transmit the image data and then output U+10EEEE placeholder
// characters with diacritics encoding row/col. Since these are just
// text characters, tmux manages them per-pane — images appear/disappear
// naturally when switching panes.
//
// Protocol:
// 1. Transmit image: ESC_G a=T,U=1,f=100,i=<id>,c=<cols>,r=<rows>,q=2; base64 ESC\
// 2. Print placeholder chars with foreground color set to image_id:
//    ESC[38;5;<id>m  <U+10EEEE><row_diac><col_diac> ... ESC[39m
//
// Diacritics: row 0 = U+0305, row 1 = U+030D, row 2 = U+030E, etc.
// See kitty docs rowcolumn-diacritics.txt

// Row/column diacritics from kitty's rowcolumn-diacritics.txt
// These are the combining characters used to encode row and column numbers
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

const PLACEHOLDER_CHAR = String.fromCodePoint(0x10EEEE);

function diacriticFor(n: number): string {
	if (n < ROW_COL_DIACRITICS.length) {
		return String.fromCodePoint(ROW_COL_DIACRITICS[n]);
	}
	// Fallback for very large values (shouldn't happen for thumbnails)
	return String.fromCodePoint(ROW_COL_DIACRITICS[0]);
}

function isInTmux(): boolean {
	return Boolean(process.env.TMUX);
}

/**
 * Wrap kitty APC sequences in DCS passthrough for tmux.
 */
function wrapForTmux(sequence: string): string {
	if (!isInTmux()) return sequence;
	return sequence.replace(
		/\x1b_G([^\x1b]*)\x1b\\/g,
		(_match, content) =>
			`\x1bPtmux;\x1b\x1b_G${content}\x1b\x1b\\\x1b\\`,
	);
}

/**
 * Transmit image and create virtual placement using Unicode placeholder mode.
 * The image data is sent to kitty but NOT displayed directly.
 * Display happens via U+10EEEE placeholder characters.
 */
function transmitImageWithPlaceholder(
	base64Data: string,
	imageId: number,
	columns: number,
	rows: number,
): void {
	// Transmit image + create virtual placement in one command
	// a=T: transmit and display, U=1: use unicode placeholders
	// q=2: suppress all responses (important in tmux)
	const CHUNK_SIZE = 4096;

	if (base64Data.length <= CHUNK_SIZE) {
		const seq = `\x1b_Ga=T,U=1,f=100,i=${imageId},c=${columns},r=${rows},q=2;${base64Data}\x1b\\`;
		process.stdout.write(wrapForTmux(seq));
	} else {
		// Chunked transfer
		let offset = 0;
		let isFirst = true;
		while (offset < base64Data.length) {
			const chunk = base64Data.slice(offset, offset + CHUNK_SIZE);
			const isLast = offset + CHUNK_SIZE >= base64Data.length;
			let seq: string;

			if (isFirst) {
				seq = `\x1b_Ga=T,U=1,f=100,i=${imageId},c=${columns},r=${rows},q=2,m=1;${chunk}\x1b\\`;
				isFirst = false;
			} else if (isLast) {
				seq = `\x1b_Gm=0;${chunk}\x1b\\`;
			} else {
				seq = `\x1b_Gm=1;${chunk}\x1b\\`;
			}

			process.stdout.write(wrapForTmux(seq));
			offset += CHUNK_SIZE;
		}
	}
}

/**
 * Delete a kitty image by ID.
 */
function deleteImage(imageId: number): void {
	const seq = `\x1b_Ga=d,d=I,i=${imageId},q=2\x1b\\`;
	process.stdout.write(wrapForTmux(seq));
}

/**
 * Build a row of Unicode placeholder characters for the given image.
 * Uses foreground color to encode image_id, diacritics to encode row/col.
 */
function buildPlaceholderRow(
	imageId: number,
	row: number,
	columns: number,
): string {
	// Set foreground color to image_id (using 24-bit true color for large IDs)
	const r = (imageId >> 16) & 0xff;
	const g = (imageId >> 8) & 0xff;
	const b = imageId & 0xff;
	const fgStart = imageId < 256
		? `\x1b[38;5;${imageId}m`
		: `\x1b[38;2;${r};${g};${b}m`;
	const fgEnd = `\x1b[39m`;

	let line = fgStart;

	// First cell: full diacritics (row + col)
	line += PLACEHOLDER_CHAR + diacriticFor(row) + diacriticFor(0);

	// Subsequent cells: no diacritics needed — kitty auto-increments
	// column index from the left neighbor's col diacritic
	for (let col = 1; col < columns; col++) {
		line += PLACEHOLDER_CHAR;
	}

	line += fgEnd;
	return line;
}

// ── Gallery Component ──────────────────────────────────────

/**
 * Renders image thumbnails above the editor using kitty's Unicode
 * placeholder protocol. Images are part of the text buffer, so
 * tmux manages them per-pane — no ghosting across panes.
 */
export class ImageGallery implements Component {
	private images: GalleryImage[] = [];
	private theme: GalleryTheme;
	private detailArmed = false;
	private cachedLines?: string[];
	private cachedWidth?: number;
	private activeImageIds: number[] = [];

	constructor(theme: GalleryTheme) {
		this.theme = theme;
	}

	setImages(images: GalleryImage[]): void {
		this.images = images;
		this.invalidate();
	}

	setDetailArmed(armed: boolean): void {
		this.detailArmed = armed;
		this.invalidate();
	}

	invalidate(): void {
		this.cachedLines = undefined;
		this.cachedWidth = undefined;
	}

	dispose(): void {
		for (const id of this.activeImageIds) {
			deleteImage(id);
		}
		this.activeImageIds = [];
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) {
			return this.cachedLines;
		}

		// Delete previous images before re-rendering
		for (const id of this.activeImageIds) {
			deleteImage(id);
		}
		this.activeImageIds = [];

		if (this.images.length === 0) {
			this.cachedLines = [];
			this.cachedWidth = width;
			return this.cachedLines;
		}

		const lines: string[] = [];
		const imageProtocol = detectImageProtocol();

		// Header — shows the resolution the next submission will use, and how to
		// toggle it with ctrl+q.
		const count = this.images.length;
		const countText = count === 1 ? "1 image" : `${count} images`;
		const headerText = this.detailArmed
			? ` 📎 ${countText} attached · 1280px detail armed`
			: ` 📎 ${countText} attached · 480p preview`;
		const headerHint = this.detailArmed ? " (ctrl+q to revert)" : " (ctrl+q → 1280)";
		lines.push(this.theme.accent(headerText) + this.theme.dim(headerHint));

		const allPng = this.images.every((image) => image.mimeType === "image/png");
		if (imageProtocol === "kitty" && allPng) {
			this.renderKittyHorizontal(lines, width);
		} else {
			this.renderTextFallback(lines);
		}

		this.cachedLines = lines;
		this.cachedWidth = width;
		return this.cachedLines;
	}

	private renderKittyHorizontal(lines: string[], width: number): void {
		// Calculate per-image thumb width so they all fit side by side
		const available = width - 2; // padding
		const totalGaps = Math.max(0, this.images.length - 1) * GAP;
		const thumbWidth = Math.min(
			THUMB_MAX_WIDTH,
			Math.floor((available - totalGaps) / this.images.length),
		);

		if (thumbWidth < 4) {
			// Too narrow for horizontal, fall back to text
			this.renderTextFallback(lines);
			return;
		}

		// Prepare each image: transmit data, calculate rows
		const imageInfos: { imageId: number; rows: number; cols: number }[] = [];

		for (const img of this.images) {
			// getImageDimensions returns null for corrupt or unrecognised image data;
			// fall back to a common aspect ratio so the thumbnail still renders.
			const dims = getImageDimensions(img.data, img.mimeType) || {
				widthPx: 800,
				heightPx: 600,
			};

			const rows = Math.min(
				calculateImageRows(dims, thumbWidth, getCellDimensions()),
				THUMB_MAX_ROWS,
			);
			const imageId = allocateImageId();
			this.activeImageIds.push(imageId);

			transmitImageWithPlaceholder(img.data, imageId, thumbWidth, rows);
			imageInfos.push({ imageId, rows, cols: thumbWidth });
		}

		const maxRows = Math.max(...imageInfos.map((i) => i.rows));

		// Build horizontal rows: each line has placeholder chars for all images side by side
		for (let row = 0; row < maxRows; row++) {
			let line = " ";
			for (let i = 0; i < this.images.length; i++) {
				const info = imageInfos[i];

				if (row < info.rows) {
					// Output placeholder chars for this image at this row
					line += buildPlaceholderRow(info.imageId, row, info.cols);
				} else {
					// Image is shorter, pad with spaces
					line += " ".repeat(info.cols);
				}

				if (i < this.images.length - 1) {
					line += " ".repeat(GAP);
				}
			}
			lines.push(line);
		}

		// Label row beneath images — middle-truncate and center
		let labelLine = " ";
		for (let i = 0; i < this.images.length; i++) {
			const cols = imageInfos[i].cols;
			let label = this.images[i].label;

			// Middle-truncate: "pi-clipboard-044c...21ad4.png"
			if (label.length > cols) {
				const keep = cols - 1; // 1 char for …
				const head = Math.ceil(keep / 2);
				const tail = keep - head;
				label = label.slice(0, head) + "…" + label.slice(-tail);
			}

			// Center the label within the column width
			const totalPad = Math.max(0, cols - label.length);
			const leftPad = Math.floor(totalPad / 2);
			const rightPad = totalPad - leftPad;
			const padded = " ".repeat(leftPad) + label + " ".repeat(rightPad);
			labelLine += this.theme.dim(padded);

			if (i < this.images.length - 1) {
				labelLine += " ".repeat(GAP);
			}
		}
		lines.push(labelLine);
	}

	private renderTextFallback(lines: string[]): void {
		for (const img of this.images) {
			lines.push(
				this.theme.muted(`  ${img.label}`),
			);
		}
	}
}
