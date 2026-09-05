import { pathToFileURL } from "node:url";

const BLOB_NAME = String.raw`[a-f0-9]{64}\.(?:png|jpg|gif|webp)`;
const INTERNAL_REFERENCE = String.raw`image-view:\/\/sha256\/${BLOB_NAME}`;
const FILE_REFERENCE = String.raw`file:\/\/\/[^)\n]*\/image-view\/blobs\/${BLOB_NAME}`;
const TARGET = `(?:${INTERNAL_REFERENCE}|${FILE_REFERENCE})`;
const BRACKETED_REFERENCE_RE = new RegExp(
	String.raw`\[\[Image #(\d+)\]\]\((${TARGET})\)`,
	"g",
);
const LEGACY_REFERENCE_RE = new RegExp(
	String.raw`\[Image #(\d+)\]\((${TARGET})\)`,
	"g",
);

function isSupportedReference(reference: string): boolean {
	return new RegExp(String.raw`^${TARGET}$`).test(reference);
}

export function createImageMarkerLink(label: string, reference: string): string {
	if (!/^\[Image #\d+\]$/.test(label) || !isSupportedReference(reference)) return label;
	return `[${label}](${reference})`;
}

export function stripImageMarkerLinks(text: string): string {
	return text
		.replace(BRACKETED_REFERENCE_RE, "[Image #$1]")
		.replace(LEGACY_REFERENCE_RE, "[Image #$1]");
}

function renderReference(
	index: string,
	reference: string,
	resolvePath: (reference: string) => string | undefined,
): string {
	if (reference.startsWith("file://")) {
		return `[[Image #${index}]](${reference})`;
	}
	const filePath = resolvePath(reference);
	return filePath
		? `[[Image #${index}]](${pathToFileURL(filePath).href})`
		: `[Image #${index}]`;
}

export function renderImageMarkerLinks(
	markdown: string,
	resolvePath: (reference: string) => string | undefined,
): string {
	return markdown
		.replace(BRACKETED_REFERENCE_RE, (_match, index: string, reference: string) =>
			renderReference(index, reference, resolvePath),
		)
		.replace(LEGACY_REFERENCE_RE, (_match, index: string, reference: string) =>
			renderReference(index, reference, resolvePath),
		);
}

const OMITTED_IMAGE_PLACEHOLDER = "[Image omitted from model context]";

type ModelMessage = {
	role?: unknown;
	content?: unknown;
};

function isImageBlock(block: unknown): boolean {
	return Boolean(block && typeof block === "object" && "type" in block && block.type === "image");
}

/** Build model-facing copies without changing session messages or their content blocks. */
export function sanitizeModelMessages<T extends ModelMessage>(
	messages: T[],
	removeImagesBefore?: number,
): T[] {
	return messages.map((message, messageIndex) => {
		if (typeof message.content === "string") {
			const content = stripImageMarkerLinks(message.content);
			return content === message.content ? message : { ...message, content };
		}
		if (!Array.isArray(message.content)) return message;

		const keepImages = removeImagesBefore === undefined || messageIndex >= removeImagesBefore;
		let changed = false;
		let removedImage = false;
		const content = message.content.flatMap((block) => {
			if (isImageBlock(block) && !keepImages) {
				changed = true;
				removedImage = true;
				return [];
			}
			if (!block || typeof block !== "object" || !("type" in block) || block.type !== "text" || !("text" in block) || typeof block.text !== "string") return [block];
			const text = stripImageMarkerLinks(block.text);
			if (text === block.text) return [block];
			changed = true;
			return [{ ...block, text }];
		});
		if (removedImage && content.length === 0) {
			content.push({ type: "text", text: OMITTED_IMAGE_PLACEHOLDER });
		}
		return changed ? { ...message, content } : message;
	});
}
