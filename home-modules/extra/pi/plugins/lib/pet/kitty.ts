// Kitty graphics protocol writer for the pi desktop pet.
//
// The pet is a terminal-driven kitty animation. Transmission and placement are
// deliberately SEPARATE channels:
//
//   - buildTransmitChunks(): per-frame chunk chains (root frame a=t —
//     transmit WITHOUT displaying, so no stray placement lands at the cursor;
//     animation frames a=f; loop start a=a s=3 v=1 — kitty animates the image
//     itself, with zero further work from pi). Returned as ONE STRING PER
//     FRAME: a frame's m=1 continuation chain must be written in a single
//     stdout burst (kitty attributes continuation chunks — which carry no
//     image id — to the transmission in progress, so an interleaved transfer
//     from another writer mid-chain corrupts both). Written directly to
//     stdout when an animation is transmitted for the first time; pet.ts
//     keeps transmitted animations alive in an LRU and replays them
//     placement-only, so old image data is freed by the cache's eviction,
//     not here.
//   - placementLine(): a tiny placement-only image line returned by the
//     overlay component's render(). pi's alt-screen renderer recognizes
//     \x1b_G lines, caches uploaded image ids, and re-emits placements on
//     repaint — so row repaints (the statusline footer shares the pet's rows
//     and ticks constantly) cost one a=p and NEVER retransmit frames.
//     Retransmitting an existing image id would delete and re-create it,
//     resetting the animation to frame 1 — which is exactly why the
//     transmission must never ride inside a rendered line.
//
// Spec notes baked in: animation-frame continuation chunks must repeat a=f;
// the root frame's gap can only be set via a=a r=1 z=<ms>; C=1 on placements
// keeps kitty from moving the cursor (pi's placement cache preserves the C).

/** Chunk base64 payload into 4096-byte APC continuation escape codes.
 * frameData: continuation chunks repeat a=f (required for animation frames). */
function chunked(control: string, b64: string, frameData = false): string {
	const cont = frameData ? "a=f," : "";
	if (b64.length <= 4096) return `\x1b_G${control};${b64}\x1b\\`;
	let out = "";
	let offset = 0;
	let first = true;
	while (offset < b64.length) {
		const chunk = b64.slice(offset, offset + 4096);
		const last = offset + 4096 >= b64.length;
		if (first) {
			out += `\x1b_G${control},m=${last ? 0 : 1};${chunk}\x1b\\`;
			first = false;
		} else {
			out += `\x1b_G${cont}m=${last ? 0 : 1};${chunk}\x1b\\`;
		}
		offset += 4096;
	}
	return out;
}

export interface TransmitOptions {
	imageId: number;
	/** Base64 PNG frames; frame 0 becomes the root frame. */
	frames: string[];
	/** Gap between frames in ms (uniform). */
	gapMs: number;
}

/**
 * Build the transmit + loop-start sequences for an animation, ONE STRING PER
 * FRAME (frame 0 transmits with a=t, the rest append with a=f; the loop-start
 * controls ride with the last frame). Each string is a complete m=1 chunk
 * chain that must be written in a single stdout burst — splitting a chain
 * across event-loop turns lets another writer's kitty transfer interleave,
 * and kitty attributes continuation chunks to whatever transmission is in
 * progress, corrupting both. Written to stdout directly (never rendered): APC
 * sequences carry no cursor movement, so interleaving whole chains with pi's
 * output frames is safe.
 */
export function buildTransmitChunks(opts: TransmitOptions): string[] {
	const { imageId, frames, gapMs } = opts;
	const out = frames.map((b64, i) =>
		// lowercase a=t transmits WITHOUT displaying (uppercase T would also
		// place the image at the current cursor position — a stray ghost
		// placement).
		i === 0
			? chunked(`a=t,i=${imageId},f=100,q=2`, b64)
			: chunked(`a=f,i=${imageId},f=100,q=2,z=${gapMs}`, b64, true)
	);
	// Root frame gap (a=f's z only sets gaps for frames 2..N), then run the
	// loop forever (s=3, v=1).
	out[out.length - 1] += `\x1b_Ga=a,i=${imageId},r=1,z=${gapMs},q=2\x1b\\`;
	out[out.length - 1] += `\x1b_Ga=a,i=${imageId},s=3,v=1,q=2\x1b\\`;
	return out;
}

/**
 * Placement-only image line for the overlay component's render(). Stable
 * bytes: pi's renderer diffs lines raw and swaps cached uploads for
 * placement re-emits, so this line must never embed image data.
 */
export function placementLine(imageId: number, cols: number, rows: number, placementId = 1): string {
	return `\x1b_Ga=p,i=${imageId},p=${placementId},c=${cols},r=${rows},q=2,C=1\x1b\\`;
}

/** Delete an image and free its data (uppercase I). */
export function deleteImageLine(imageId: number): string {
	return `\x1b_Ga=d,d=I,i=${imageId},q=2\x1b\\`;
}

/**
 * Delete only an image's placements, keeping its transmitted data (lowercase
 * d=i). Used when switching animations: the previous animation's placement
 * must go away (otherwise old and new render stacked in the same cells), but
 * its frames stay alive for cache replays.
 */
export function deletePlacementLine(imageId: number): string {
	return `\x1b_Ga=d,d=i,i=${imageId},q=2\x1b\\`;
}

/** Scale an image (pixel dims) to fit a cell box, returning cell dims. */
export function fitCells(
	widthPx: number,
	heightPx: number,
	maxCols: number,
	maxRows: number,
	cellWidthPx: number,
	cellHeightPx: number,
): { cols: number; rows: number } {
	const scale = Math.min(
		(maxCols * cellWidthPx) / widthPx,
		(maxRows * cellHeightPx) / heightPx,
	);
	return {
		cols: Math.max(1, Math.min(maxCols, Math.ceil((widthPx * scale) / cellWidthPx))),
		rows: Math.max(1, Math.min(maxRows, Math.ceil((heightPx * scale) / cellHeightPx))),
	};
}
