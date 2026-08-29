import type { ContentBlock, ImageContent, TextContent } from "./content.ts";
import {
	collectTextContent,
	extractSavedScreenshotPaths,
	hasInlineImageContent,
	isScreenshotToolResult,
	resolveMaybeRelativePath,
} from "./path-utils.ts";

export type ToolResultEventLike = {
	toolName: string;
	content: ContentBlock[];
	details?: unknown;
	isError: boolean;
};

export async function upgradeScreenshotToolResult(
	event: ToolResultEventLike,
	cwd: string,
	loadImageFromPath: (filePath: string) => Promise<ImageContent | null>,
	resizeImage?: (image: ImageContent) => Promise<ImageContent>,
): Promise<{ content: ContentBlock[] } | undefined> {
	if (event.isError || !isScreenshotToolResult(event)) return undefined;

	if (hasInlineImageContent(event.content)) {
		if (!resizeImage) return undefined;
		const content = await Promise.all(
			event.content.map((block) => block.type === "image" ? resizeImage(block) : Promise.resolve(block)),
		);
		return { content };
	}

	const text = collectTextContent(event.content);
	const savedPaths = extractSavedScreenshotPaths(text);
	if (savedPaths.length === 0) return undefined;

	const images: ImageContent[] = [];
	for (const rawPath of savedPaths) {
		const resolvedPath = resolveMaybeRelativePath(rawPath, cwd);
		const image = await loadImageFromPath(resolvedPath);
		if (image) {
			images.push(resizeImage ? await resizeImage(image) : image);
		}
	}

	if (images.length > 0) {
		return { content: [...event.content, ...images] };
	}

	const hint: TextContent = {
		type: "text",
		text: "[pi-image-view: screenshot was saved via filePath but the image file was not readable. If you need to inspect the screenshot agentically, retry the screenshot tool without filePath so the image is returned inline.]",
	};
	return { content: [...event.content, hint] };
}
