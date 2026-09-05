import path from "node:path";
import type { ImageContent } from "./content.ts";
import {
	createImageMarkerLink,
	renderImageMarkerLinks,
	sanitizeModelMessages,
} from "./attachment-links.ts";
import { ImageGallery, type GalleryImage } from "./image-gallery.ts";
import { extractImagePaths } from "./image-paths.ts";
import { upgradeScreenshotToolResult } from "./tool-result-upgrader.ts";
import { debugLog } from "./debug.ts";
import { matchesKey } from "@earendil-works/pi-tui";

// ── Types ──────────────────────────────────────────────────

type TrackedImage = {
	filePath: string;
	placeholder: string;
	/** Source image used to build the submitted preview. */
	image: ImageContent;
	/** Small PNG thumbnail used for both inline preview and model submission. */
	previewImage?: ImageContent;
	previewPromise?: Promise<ImageContent>;
	label: string;
};

export type ExtensionDeps = {
	readImageContentFromPathAsync: (
		filePath: string,
	) => Promise<ImageContent | null>;
	maybeResizeImage?: (image: ImageContent) => Promise<ImageContent>;
	resizeDetailImage?: (image: ImageContent) => Promise<ImageContent>;
	normalizeImageForMatching?: (image: ImageContent) => Promise<ImageContent>;
	createAtomicEditor?: (tui: unknown, theme: unknown, keybindings: unknown, attachImage: (image: ImageContent) => string, baseEditor?: object) => unknown;
	/** Resolves before installing the custom editor so unavailable clipboard backends keep Pi paste intact. */
	supportsAtomicEditor?: () => Promise<boolean>;
	isImagePasteInput?: (data: string) => boolean;
	loadImageContentFromPath: (
		filePath: string,
	) => Promise<ImageContent | null>;
	storeImage?: (image: ImageContent) => Promise<string | undefined>;
	resolveImageReference?: (reference: string) => string | undefined;
};

type PiLike = {
	on(event: string, handler: (...args: any[]) => any): void;
	registerCommand?: (name: string, options: { description?: string; handler: (args: string, ctx: CtxLike) => Promise<void> | void }) => void;
	registerMarkdownTransformer?: (
		transformer: (markdown: string, context: { messageType: string }) => string,
	) => void;
};

type CtxLike = {
	cwd: string;
	hasUI?: boolean;
	mode?: "tui" | "rpc" | "json" | "print";
	sessionManager?: { getBranch(): readonly unknown[] };
	isIdle(): boolean;
	ui: {
		getEditorComponent?(): ((tui: unknown, theme: unknown, keybindings: unknown) => unknown) | undefined;
		onTerminalInput?(handler: (data: string) => { consume?: boolean; data?: string } | undefined): () => void;
		setEditorComponent?(factory: ((tui: unknown, theme: unknown, keybindings: unknown) => unknown) | undefined): void;
		setWidget(
			key: string,
			content:
				| string[]
				| ((tui: any, theme: any) => any)
				| undefined,
			options?: { placement?: "aboveEditor" | "belowEditor" },
		): void;
		getEditorText(): string;
		setEditorText(text: string): void;
		notify(message: string, type?: "info" | "warning" | "error"): void;
		theme: any;
	};
};

/** Event shape for the "input" event from pi. */
type InputEvent = {
	text: string;
	images?: ImageContent[];
};

/** Discriminated union for input handler return values. */
type InputResult =
	| { action: "continue" }
	| { action: "handled" }
	| { action: "transform"; text: string; images: ImageContent[] };

/** Re-export for tool_result event typing. */
type ToolResultEvent = import("./tool-result-upgrader.ts").ToolResultEventLike;

// ── Constants ──────────────────────────────────────────────

const WIDGET_KEY = "image-view";
const POLL_INTERVAL_MS = 250;
const IMAGE_PLACEHOLDER_RE = /\[Image #\d+\]/g;

function placeholdersIn(text: string): Set<string> {
	return new Set(text.match(IMAGE_PLACEHOLDER_RE) ?? []);
}

function highestImageNumberInText(text: string): number {
	let highest = 0;
	for (const match of text.matchAll(/\[Image #(\d+)\]/g)) {
		const value = Number(match[1]);
		if (Number.isSafeInteger(value)) highest = Math.max(highest, value);
	}
	return highest;
}

function highestImageNumberInContent(content: unknown): number {
	if (typeof content === "string") return highestImageNumberInText(content);
	if (!Array.isArray(content)) return 0;
	return content.reduce((highest, part) => {
		if (typeof part === "string") return Math.max(highest, highestImageNumberInText(part));
		if (!part || typeof part !== "object") return highest;
		const text = (part as { text?: unknown }).text;
		return typeof text === "string"
			? Math.max(highest, highestImageNumberInText(text))
			: highest;
	}, 0);
}

export function nextImageNumberForBranch(entries: readonly unknown[]): number {
	let highest = 0;
	for (const entry of entries) {
		if (!entry || typeof entry !== "object") continue;
		const candidate = entry as { type?: unknown; message?: { role?: unknown; content?: unknown } };
		if (candidate.type !== "message" || candidate.message?.role !== "user") continue;
		highest = Math.max(highest, highestImageNumberInContent(candidate.message.content));
	}
	return highest + 1;
}

/** Produce a label from an image path — just the filename. */
function trimImageLabel(filePath: string): string {
	return path.basename(filePath);
}

// ── Extension ──────────────────────────────────────────────

export function registerImagePreviewExtension(
	pi: PiLike,
	deps: ExtensionDeps,
): void {
	if (pi.registerMarkdownTransformer && deps.resolveImageReference) {
		pi.registerMarkdownTransformer((markdown, context) =>
			context.messageType === "user"
				? renderImageMarkerLinks(markdown, deps.resolveImageReference!)
				: markdown,
		);
	}

	let clearBeforeIndex: number | undefined;
	let clearOnNextContext = false;
	let lastContextMessageCount = 0;
	let detailNextSubmission = false;

	pi.registerCommand?.("pi-image-view", {
		description: "Clear existing image context or arm 1280px detail mode (or press ctrl+q with images attached)",
		handler: (args, ctx) => {
			const action = args.trim();
			if (action === "detail") {
				detailNextSubmission = true;
				ctx.ui.notify("Next image submission will use 1280px detail mode", "info");
				return;
			}
			if (action !== "clear") {
				ctx.ui.notify("Usage: /pi-image-view [clear|detail]", "error");
				return;
			}
			if (lastContextMessageCount > 0) {
				clearBeforeIndex = lastContextMessageCount;
				clearOnNextContext = false;
			} else {
				clearOnNextContext = true;
			}
			ctx.ui.notify("Existing images cleared from model context", "info");
		},
	});

	pi.on("context", (event: { messages: Array<{ role?: unknown; content?: unknown }> }) => {
		if (clearBeforeIndex !== undefined && event.messages.length < lastContextMessageCount) {
			const removedPrefixLength = lastContextMessageCount - event.messages.length;
			clearBeforeIndex = Math.max(0, clearBeforeIndex - removedPrefixLength);
		}
		if (clearOnNextContext) {
			let latestUserIndex = -1;
			for (let index = event.messages.length - 1; index >= 0; index -= 1) {
				if (event.messages[index]?.role === "user") {
					latestUserIndex = index;
					break;
				}
			}
			clearBeforeIndex = latestUserIndex >= 0 ? latestUserIndex : event.messages.length;
			clearOnNextContext = false;
		}
		lastContextMessageCount = event.messages.length;
		return { messages: sanitizeModelMessages(event.messages, clearBeforeIndex) };
	});

	type EditorFactory = (tui: unknown, theme: unknown, keybindings: unknown) => unknown;
	let installedEditorFactory: EditorFactory | undefined;
	let previousEditorFactory: EditorFactory | undefined;
	/** Set once a displaced factory throws, so shutdown never hands it back. */
	let previousEditorFactoryFailed = false;
	let tracked: Map<string, TrackedImage> = new Map();
	let gallery: ImageGallery | null = null;
	let pollTimer: ReturnType<typeof setInterval> | null = null;
	let unsubscribeTerminalInput: (() => void) | undefined;
	const pasteScanTimers = new Set<ReturnType<typeof setTimeout>>();
	let latestCtx: CtxLike | null = null;
	let nextPlaceholderNumber = 1;
	let scanInFlight = false;
	let scanGeneration = 0;
	let lastScannedText: string | undefined;
	let failedScanText: string | undefined;
	let failedScanAttempts = 0;
	let sessionGeneration = 0;

	// ── Helpers ────────────────────────────────────────────


	function allocatePlaceholder(existingText = "", existing = tracked): string {
		let placeholder: string;
		do {
			placeholder = `[Image #${nextPlaceholderNumber++}]`;
		} while (existingText.includes(placeholder) || existing.has(placeholder));
		return placeholder;
	}

	function attachClipboardImage(image: ImageContent): string {
		let editorText = "";
		try { editorText = latestCtx?.ui.getEditorText() ?? ""; } catch { /* editor unavailable during teardown */ }
		const placeholder = allocatePlaceholder(editorText);
		const extension = image.mimeType === "image/jpeg" ? "jpg" : image.mimeType.split("/")[1] || "png";
		const entry: TrackedImage = {
			filePath: `clipboard.${extension}`,
			placeholder,
			image,
			label: `clipboard.${extension}`,
		};
		tracked.set(placeholder, entry);
		if (deps.maybeResizeImage) void ensurePreview(entry);
		else if (latestCtx) refreshWidget(latestCtx);
		return placeholder;
	}

	function ensurePreview(entry: TrackedImage): Promise<ImageContent> {
		if (entry.previewImage) return Promise.resolve(entry.previewImage);
		if (!deps.maybeResizeImage) return Promise.resolve(entry.image);
		if (!entry.previewPromise) {
			entry.previewPromise = deps.maybeResizeImage(entry.image)
				.then((preview) => {
					entry.previewImage = preview;
					if (latestCtx && tracked.get(entry.placeholder) === entry) refreshWidget(latestCtx);
					return preview;
				})
				.catch((error) => {
					debugLog(`Failed to resize image ${entry.filePath}`, error);
					return entry.image;
				});
		}
		return entry.previewPromise;
	}

	function refreshWidget(ctx: CtxLike): void {
		if (tracked.size === 0) {
			if (gallery) {
				gallery.dispose();
				gallery = null;
			}
			ctx.ui.setWidget(WIDGET_KEY, undefined);
			return;
		}

		const galleryImages: GalleryImage[] = [...tracked.values()].map((t) => {
			const preview = t.previewImage ?? t.image;
			return {
				data: preview.data,
				mimeType: preview.mimeType,
				label: t.label,
			};
		});

		// Dispose the previous gallery to free kitty image resources before replacement
		if (gallery) {
			gallery.dispose();
			gallery = null;
		}

		ctx.ui.setWidget(
			WIDGET_KEY,
			(_tui: any, theme: any) => {
				const galleryTheme = {
					accent: (s: string) => theme.fg("accent", s),
					muted: (s: string) => theme.fg("muted", s),
					dim: (s: string) => theme.fg("dim", s),
					bold: (s: string) => theme.bold(s),
				};

				gallery = new ImageGallery(galleryTheme);
				gallery.setImages(galleryImages);
				gallery.setDetailArmed(detailNextSubmission);
				return gallery;
			},
			{ placement: "aboveEditor" },
		);
	}

	function resetDraft(ctx: CtxLike): void {
		if (gallery) {
			gallery.dispose();
			gallery = null;
		}
		tracked = new Map();
		scanGeneration += 1;
		lastScannedText = undefined;
		failedScanText = undefined;
		failedScanAttempts = 0;
		ctx.ui.setWidget(WIDGET_KEY, undefined);
	}

	/**
	 * Scan editor text for image paths.
	 * Track new ones, remove ones that are no longer in the text.
	 * Async to avoid blocking the event loop with file I/O.
	 */
	async function scanEditorText(ctx: CtxLike): Promise<void> {
		let text: string;
		try {
			text = ctx.ui.getEditorText();
		} catch (err) {
			debugLog("Failed to get editor text", err);
			return;
		}
		if (text === lastScannedText) return;
		if (text !== failedScanText) {
			failedScanText = text;
			failedScanAttempts = 0;
		}
		lastScannedText = text;
		const generation = ++scanGeneration;
		if (scanInFlight) return;

		scanInFlight = true;
		try {
			const visiblePlaceholders = placeholdersIn(text);
			const nextTracked = new Map(tracked);
			let changed = false;
			for (const placeholder of nextTracked.keys()) {
				if (!visiblePlaceholders.has(placeholder)) {
					nextTracked.delete(placeholder);
					changed = true;
				}
			}

			let renderedText = text;
			let hadReadFailure = false;
			const newEntries: TrackedImage[] = [];
			for (const { raw, path: filePath } of extractImagePaths(text, { cwd: ctx.cwd })) {
				const image = await deps.readImageContentFromPathAsync(filePath);
				if (generation !== scanGeneration) {
					lastScannedText = undefined;
					return;
				}
				if (!image) {
					hadReadFailure = true;
					continue;
				}

				const placeholder = allocatePlaceholder(renderedText, nextTracked);

				const entry: TrackedImage = {
					filePath,
					placeholder,
					image,
					label: trimImageLabel(filePath),
				};
				nextTracked.set(placeholder, entry);
				newEntries.push(entry);
				renderedText = renderedText.replace(raw, placeholder);
				changed = true;
			}

			if (generation !== scanGeneration) {
				lastScannedText = undefined;
				return;
			}
			tracked = nextTracked;
			if (renderedText !== text) {
				ctx.ui.setEditorText(renderedText);
				lastScannedText = renderedText;
			}
			if (changed) refreshWidget(ctx);
			for (const entry of newEntries) {
				if (deps.maybeResizeImage) void ensurePreview(entry);
			}
			if (hadReadFailure) {
				failedScanAttempts += 1;
				if (failedScanAttempts < 3) lastScannedText = undefined;
			} else {
				failedScanText = undefined;
				failedScanAttempts = 0;
			}
		} finally {
			scanInFlight = false;
		}
	}

	function schedulePasteScans(ctx: CtxLike): void {
		for (const timer of pasteScanTimers) clearTimeout(timer);
		pasteScanTimers.clear();
		for (const delay of [0, 16, 40, 80, 160, 240]) {
			const timer = setTimeout(() => {
				pasteScanTimers.delete(timer);
				scanEditorText(ctx).catch((error) => debugLog("Paste-triggered image scan failed", error));
			}, delay);
			timer.unref?.();
			pasteScanTimers.add(timer);
		}
	}

	function startPolling(): void {
		stopPolling();
		pollTimer = setInterval(() => {
			if (!latestCtx) return;
			scanEditorText(latestCtx).catch((err) => {
				debugLog("Error during editor text scan", err);
			});
		}, POLL_INTERVAL_MS);
		// Don't let the poll timer keep the Node event loop alive.
		// In non-interactive modes (e.g. `pi --print`), the process must be
		// able to exit once work is done — an active interval would block exit.
		if (typeof pollTimer.unref === "function") {
			pollTimer.unref();
		}
	}

	function stopPolling(): void {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = null;
		}
	}

	// ── Event handlers ─────────────────────────────────────

	const cleanup = (): void => {
		stopPolling();
		unsubscribeTerminalInput?.();
		unsubscribeTerminalInput = undefined;
		for (const timer of pasteScanTimers) clearTimeout(timer);
		pasteScanTimers.clear();
		scanGeneration += 1;
		sessionGeneration += 1;
		lastScannedText = undefined;
		latestCtx = null;
		if (gallery) {
			gallery.dispose();
			gallery = null;
		}
	};

	pi.on("session_start", async (_event: unknown, ctx: CtxLike) => {
		const generation = ++sessionGeneration;
		clearBeforeIndex = undefined;
		detailNextSubmission = false;
		clearOnNextContext = false;
		lastContextMessageCount = 0;
		latestCtx = ctx;
		resetDraft(ctx);
		nextPlaceholderNumber = nextImageNumberForBranch(ctx.sessionManager?.getBranch() ?? []);
		if (deps.createAtomicEditor && ctx.ui.setEditorComponent) {
			let supported = true;
			try {
				if (deps.supportsAtomicEditor) supported = await deps.supportsAtomicEditor();
			} catch (error) {
				supported = false;
				debugLog("Direct clipboard capability detection failed", error);
			}
			// A shutdown or a newer session may have won while capability detection ran.
			// Stop the obsolete handler before *all* later startup side effects.
			if (generation !== sessionGeneration || latestCtx !== ctx) return;
			if (supported) {
				previousEditorFactory = ctx.ui.getEditorComponent?.();
				previousEditorFactoryFailed = false;
				const previous = previousEditorFactory;
				installedEditorFactory = (tui, theme, keybindings) => {
					// A displaced factory belongs to another extension. If it throws, build
					// our own editor rather than leaving the session with no editor at all.
					let baseEditor: unknown;
					try {
						baseEditor = previous?.(tui, theme, keybindings);
					} catch (error) {
						debugLog("Displaced editor factory failed; building a standalone editor", error);
						previousEditorFactoryFailed = true;
						baseEditor = undefined;
					}
					return deps.createAtomicEditor!(tui, theme, keybindings, attachClipboardImage, baseEditor && typeof baseEditor === "object" ? baseEditor : undefined);
				};
				for (const name of ["pi-zentui.editor-factory", "pi-zentui.editor-owner", "pi-zentui.editor-base-factory"] as const) {
					const symbol = Symbol.for(name);
					const value = previous ? (previous as unknown as Record<symbol, unknown>)[symbol] : undefined;
					if (value !== undefined) Object.defineProperty(installedEditorFactory, symbol, { value });
				}
				ctx.ui.setEditorComponent(installedEditorFactory);
			}
		}
		if (ctx.hasUI !== false && ctx.mode !== "print" && ctx.mode !== "json") {
			startPolling();
			if (deps.isImagePasteInput && ctx.ui.onTerminalInput) {
				unsubscribeTerminalInput = ctx.ui.onTerminalInput((data) => {
					if (deps.isImagePasteInput!(data)) schedulePasteScans(ctx);
					// ctrl+q toggles 480p preview ↔ 1280px detail for the next
					// submission, but only while images are pending in the editor
					// (ctrl+q is unbound otherwise, so it passes through).
					if (tracked.size > 0 && matchesKey(data, "ctrl+q")) {
						detailNextSubmission = !detailNextSubmission;
						refreshWidget(ctx);
						try {
							ctx.ui.notify(
								detailNextSubmission
									? "Next image submission will use 1280px detail mode"
									: "Image submission reverted to 480p preview",
								"info",
							);
						} catch {
							// notify may be unavailable while a dialog owns the UI
						}
						return { consume: true };
					}
					return undefined;
				});
			}
		}
	});

	pi.on("session_shutdown", (_event: unknown, ctx: CtxLike) => {
		cleanup();
		const installed = installedEditorFactory;
		const previousIsZentui = Boolean(previousEditorFactory && (previousEditorFactory as unknown as Record<symbol, unknown>)[Symbol.for("pi-zentui.editor-factory")]);
		// Zentui tears its own editor down, and a factory that already threw would
		// throw again: `setEditorComponent` invokes the factory synchronously, so
		// either one would break teardown rather than restore anything.
		const previous = previousIsZentui || previousEditorFactoryFailed ? undefined : previousEditorFactory;
		const ui = ctx.ui;
		/** Restoring runs foreign code, so never let it escape the shutdown handler. */
		const restore = (factory: EditorFactory | undefined): void => {
			try {
				ui.setEditorComponent?.(factory);
			} catch (error) {
				debugLog("Restoring the displaced editor factory failed; clearing it", error);
				try { ui.setEditorComponent?.(undefined); } catch { /* disposed UI */ }
			}
		};
		if (installed && ui.getEditorComponent?.() === installed) {
			restore(previous);
		} else if (installed) {
			const timer = setTimeout(() => {
				try {
					if (ui.getEditorComponent?.() === installed) restore(previous);
				} catch { /* disposed UI */ }
			}, 0);
			timer.unref?.();
		}
		installedEditorFactory = undefined;
		previousEditorFactory = undefined;
		previousEditorFactoryFailed = false;
	});

	pi.on("tool_result", async (event: ToolResultEvent, ctx: CtxLike) => {
		latestCtx = ctx;
		return upgradeScreenshotToolResult(
			event,
			ctx.cwd,
			deps.loadImageContentFromPath,
			deps.maybeResizeImage,
		);
	});

	// On submit: remove local placeholders/paths and attach the same image content.
	pi.on("input", async (event: InputEvent, ctx: CtxLike): Promise<InputResult> => {
		latestCtx = ctx;
		const fullText = (event.text || "").trim();

		const detectedPaths = extractImagePaths(fullText, { cwd: ctx.cwd });
		if (
			(fullText.startsWith("/") && detectedPaths.length === 0) ||
			fullText.trimStart().startsWith("!")
		) {
			return { action: "continue" };
		}

		const candidates: Array<{ token: string; entry: TrackedImage; index: number }> = [];
		for (const [placeholder, entry] of tracked) {
			const index = fullText.indexOf(placeholder);
			if (index >= 0) candidates.push({ token: placeholder, entry, index });
		}

		// Fast-submit fallback: the input event may arrive before the 250ms editor
		// poll has converted a freshly pasted path into a placeholder.
		for (const { raw, path: filePath } of detectedPaths) {
			const image = await deps.readImageContentFromPathAsync(filePath);
			if (!image) continue;
			const placeholder = allocatePlaceholder(fullText);
			candidates.push({
				token: raw,
				index: fullText.indexOf(raw),
				entry: {
					filePath,
					placeholder,
					image,
					label: trimImageLabel(filePath),
				},
			});
		}

		if (candidates.length === 0) return { action: "continue" };
		candidates.sort((a, b) => a.index - b.index);

		const existingByContent = new Map<string, number[]>();
		for (const [index, image] of (event.images ?? []).entries()) {
			const key = `${image.mimeType}\u0000${image.data}`;
			const matches = existingByContent.get(key);
			if (matches) matches.push(index);
			else existingByContent.set(key, [index]);
		}
		const existingIndexes = candidates.map(({ entry }) => {
			const key = `${entry.image.mimeType}\u0000${entry.image.data}`;
			return existingByContent.get(key)?.shift();
		});
		if (deps.normalizeImageForMatching && (event.images?.length ?? 0) > 0) {
			const normalizedCandidates = await Promise.all(
				candidates.map(({ entry }, candidateIndex) =>
					existingIndexes[candidateIndex] === undefined
						? deps.normalizeImageForMatching!(entry.image)
						: Promise.resolve(undefined),
				),
			);
			for (let candidateIndex = 0; candidateIndex < normalizedCandidates.length; candidateIndex += 1) {
				const normalized = normalizedCandidates[candidateIndex];
				if (!normalized) continue;
				const key = `${normalized.mimeType}\u0000${normalized.data}`;
				existingIndexes[candidateIndex] = existingByContent.get(key)?.shift();
			}
		}
		const preparedImages = await Promise.all(
			candidates.map(async ({ entry }, candidateIndex) => ({
				image: detailNextSubmission && deps.resizeDetailImage
					? await deps.resizeDetailImage(entry.image)
					: await ensurePreview(entry),
				existingIndex: existingIndexes[candidateIndex],
			})),
		);
		const references = await Promise.all(
			preparedImages.map(async ({ image }) => {
				if (!deps.storeImage) return undefined;
				try {
					return await deps.storeImage(image);
				} catch (error) {
					debugLog("Failed to persist image attachment", error);
					return undefined;
				}
			}),
		);
		let transformedText = fullText;
		for (let index = 0; index < candidates.length; index += 1) {
			const candidate = candidates[index]!;
			const reference = references[index];
			const marker = reference
				? createImageMarkerLink(candidate.entry.placeholder, reference)
				: candidate.entry.placeholder;
			transformedText = transformedText.replace(candidate.token, marker);
		}
		const images = [...(event.images ?? [])];
		for (const { image, existingIndex } of preparedImages) {
			if (existingIndex === undefined) images.push(image);
			else images[existingIndex] = image;
		}
		detailNextSubmission = false;
		resetDraft(ctx);
		return { action: "transform", text: transformedText, images };
	});
}
