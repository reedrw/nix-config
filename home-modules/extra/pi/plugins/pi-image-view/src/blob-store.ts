import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ImageContent } from "./content.ts";

const EXTENSION_BY_MIME: Record<string, string> = {
	"image/png": "png",
	"image/jpeg": "jpg",
	"image/jpg": "jpg",
	"image/gif": "gif",
	"image/webp": "webp",
};

export interface StoredImageBlob {
	reference: string;
	displayPath: string;
	name: string;
}

export function defaultBlobRoot(): string {
	const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
	return join(agentDir, "image-view", "blobs");
}

export async function putImageBlob(
	image: ImageContent,
	root = defaultBlobRoot(),
): Promise<StoredImageBlob> {
	const extension = EXTENSION_BY_MIME[image.mimeType.toLowerCase()];
	if (!extension) throw new Error(`Unsupported image MIME type: ${image.mimeType}`);
	const bytes = Buffer.from(image.data, "base64");
	const hash = createHash("sha256").update(bytes).digest("hex");
	const name = `${hash}.${extension}`;
	const displayPath = join(root, name);
	await mkdir(root, { recursive: true });
	try {
		await writeFile(displayPath, bytes, { flag: "wx" });
	} catch (error) {
		if (!(error && typeof error === "object" && "code" in error && error.code === "EEXIST")) throw error;
	}
	return { reference: `image-view://sha256/${name}`, displayPath, name };
}

export function resolveImageReference(
	reference: string,
	root = defaultBlobRoot(),
): string | undefined {
	const match = /^image-view:\/\/sha256\/([a-f0-9]{64}\.(?:png|jpg|gif|webp))$/.exec(reference);
	return match ? join(root, match[1]) : undefined;
}

