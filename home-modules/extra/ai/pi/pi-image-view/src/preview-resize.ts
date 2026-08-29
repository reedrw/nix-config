import type { ImageContent } from "./content.ts";

/** Thumbnails only need to fill a ~25-cell gallery slot; keep them small so the
 * data survives kitty transmission through tmux passthrough. */
export const PREVIEW_MAX_DIMENSION = 480;
export const PREVIEW_MAX_BYTES = 2 * 1024 * 1024;
export const DETAIL_MAX_DIMENSION = 1280;
export const DETAIL_MAX_BYTES = 4.5 * 1024 * 1024;

type ResizedImage = { data: string; mimeType: string };

export interface PreviewResizeDeps {
	/** Resize raw image bytes within the given bounds (pi's WASM resizer). */
	resizeImage: (
		bytes: Uint8Array,
		mimeType: string,
		options: { maxWidth: number; maxHeight: number; maxBytes: number },
	) => Promise<ResizedImage | null>;
	/** Re-encode an image as PNG (kitty's f=100 transmission requires PNG). */
	convertToPng: (
		data: string,
		mimeType: string,
	) => Promise<ResizedImage | null>;
}

/**
 * Build a small PNG thumbnail for the gallery preview. The kitty graphics
 * transmission uses f=100 (PNG), so the result is always converted to PNG;
 * a non-PNG payload would render as a blank block.
 */
export async function resizeForPreview(
	image: ImageContent,
	deps: PreviewResizeDeps,
): Promise<ImageContent> {
	try {
		const bytes = Buffer.from(image.data, "base64");
		const resized = await deps.resizeImage(bytes, image.mimeType, {
			maxWidth: PREVIEW_MAX_DIMENSION,
			maxHeight: PREVIEW_MAX_DIMENSION,
			maxBytes: PREVIEW_MAX_BYTES,
		});
		const small = resized ?? { data: image.data, mimeType: image.mimeType };
		const png = await deps.convertToPng(small.data, small.mimeType);
		const final = png ?? small;
		return { type: "image", data: final.data, mimeType: final.mimeType };
	} catch {
		return image;
	}
}

/** Build a higher-detail model payload for the next explicitly armed submission. */
export async function resizeForDetail(
	image: ImageContent,
	deps: Pick<PreviewResizeDeps, "resizeImage">,
): Promise<ImageContent> {
	try {
		const resized = await deps.resizeImage(Buffer.from(image.data, "base64"), image.mimeType, {
			maxWidth: DETAIL_MAX_DIMENSION,
			maxHeight: DETAIL_MAX_DIMENSION,
			maxBytes: DETAIL_MAX_BYTES,
		});
		return resized
			? { type: "image", data: resized.data, mimeType: resized.mimeType }
			: image;
	} catch {
		return image;
	}
}
