import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";

const IMAGE_MIME_BY_EXT: Record<string, string> = {
	png: "image/png",
	jpg: "image/jpeg",
	jpeg: "image/jpeg",
	gif: "image/gif",
	webp: "image/webp",
};

export function inferMimeType(filePath: string): string | null {
	const ext = path.extname(filePath).replace(/^\./, "").toLowerCase();
	return IMAGE_MIME_BY_EXT[ext] ?? null;
}

export function looksLikeImagePath(filePath: string): boolean {
	const mimeType = inferMimeType(filePath);
	if (!mimeType) return false;
	try {
		return fs.statSync(filePath).isFile();
	} catch {
		return false;
	}
}

/** Async version of looksLikeImagePath — preferred in the poll path to avoid blocking the event loop. */
export async function looksLikeImagePathAsync(
	filePath: string,
): Promise<boolean> {
	const mimeType = inferMimeType(filePath);
	if (!mimeType) return false;
	try {
		const stat = await fsp.stat(filePath);
		return stat.isFile();
	} catch {
		return false;
	}
}

export function resolveMaybeRelativePath(
	filePath: string,
	cwd: string,
): string {
	return path.isAbsolute(filePath) ? filePath : path.resolve(cwd, filePath);
}

export function isScreenshotToolName(toolName: string): boolean {
	return (
		toolName === "take_screenshot" ||
		toolName === "chrome_devtools_take_screenshot" ||
		toolName.endsWith("_take_screenshot")
	);
}

export function isScreenshotToolResult(event: {
	toolName: string;
	details?: unknown;
}): boolean {
	if (isScreenshotToolName(event.toolName)) return true;
	if (!event.details || typeof event.details !== "object") return false;
	const maybeTool = (event.details as { tool?: unknown }).tool;
	return typeof maybeTool === "string" && isScreenshotToolName(maybeTool);
}

const SCREENSHOT_SAVE_LINE_RE = /^Saved screenshot to\s+(.+)$/gim;

export function extractSavedScreenshotPaths(text: string): string[] {
	const paths: string[] = [];
	for (const match of text.matchAll(SCREENSHOT_SAVE_LINE_RE)) {
		const rawPath = match[1]?.trim();
		if (!rawPath) continue;
		paths.push(rawPath.replace(/\.$/, ""));
	}
	return paths;
}

export function collectTextContent(
	content: Array<{ type: string; text?: string }>,
): string {
	return content
		.filter((item) => item.type === "text" && item.text)
		.map((item) => item.text!)
		.join("\n");
}

export function hasInlineImageContent(
	content: Array<{ type: string }>,
): boolean {
	return content.some((item) => item.type === "image");
}
