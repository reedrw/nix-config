import fs from "node:fs";
import fsp from "node:fs/promises";
import type { ImageContent } from "./content.ts";
import {
	inferMimeType,
	looksLikeImagePath,
	looksLikeImagePathAsync,
} from "./path-utils.ts";
import { debugLog } from "./debug.ts";

export type ImageResizer = (image: ImageContent) => Promise<ImageContent>;

/** Maximum image file size in bytes (50 MB). Files larger than this are skipped to prevent OOM. */
const MAX_IMAGE_FILE_SIZE = 50 * 1024 * 1024;

/**
 * Synchronous image read — used only at startup / non-poll paths.
 * Prefer readImageContentFromPathAsync in the poll loop.
 */
export function readImageContentFromPath(
	filePath: string,
): ImageContent | null {
	if (!looksLikeImagePath(filePath)) return null;

	try {
		const stat = fs.statSync(filePath);
		if (stat.size > MAX_IMAGE_FILE_SIZE) {
			debugLog(
				`Skipping image ${filePath}: file size ${(stat.size / 1024 / 1024).toFixed(1)}MB exceeds ${MAX_IMAGE_FILE_SIZE / 1024 / 1024}MB limit`,
			);
			return null;
		}
	} catch (err) {
		debugLog(`Failed to stat image file ${filePath}`, err);
		return null;
	}

	const mimeType = inferMimeType(filePath)!;
	try {
		const bytes = fs.readFileSync(filePath);
		return {
			type: "image",
			data: bytes.toString("base64"),
			mimeType,
		};
	} catch (err) {
		debugLog(`Failed to read image file ${filePath}`, err);
		return null;
	}
}

/**
 * Async image read — non-blocking, preferred in the 250ms poll loop.
 */
export async function readImageContentFromPathAsync(
	filePath: string,
): Promise<ImageContent | null> {
	if (!(await looksLikeImagePathAsync(filePath))) return null;

	try {
		const stat = await fsp.stat(filePath);
		if (stat.size > MAX_IMAGE_FILE_SIZE) {
			debugLog(
				`Skipping image ${filePath}: file size ${(stat.size / 1024 / 1024).toFixed(1)}MB exceeds ${MAX_IMAGE_FILE_SIZE / 1024 / 1024}MB limit`,
			);
			return null;
		}
	} catch (err) {
		debugLog(`Failed to stat image file ${filePath}`, err);
		return null;
	}

	const mimeType = inferMimeType(filePath)!;
	try {
		const bytes = await fsp.readFile(filePath);
		return {
			type: "image",
			data: bytes.toString("base64"),
			mimeType,
		};
	} catch (err) {
		debugLog(`Failed to read image file ${filePath}`, err);
		return null;
	}
}

export async function maybeResizeImage(
	image: ImageContent,
	resizeImage?: ImageResizer | null,
): Promise<ImageContent> {
	if (!resizeImage) return image;
	try {
		return await resizeImage(image);
	} catch (err) {
		debugLog("Image resize failed, using original", err);
		return image;
	}
}

export async function loadImageContentFromPath(
	filePath: string,
	resizeImage?: ImageResizer | null,
): Promise<ImageContent | null> {
	const image = readImageContentFromPath(filePath);
	if (!image) return null;
	return maybeResizeImage(image, resizeImage);
}
