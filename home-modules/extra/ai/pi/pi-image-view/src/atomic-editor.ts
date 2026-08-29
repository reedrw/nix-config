import { CustomEditor, type KeybindingsManager } from "@earendil-works/pi-coding-agent";
import type { EditorTheme, TUI } from "@earendil-works/pi-tui";
import { debugLog } from "./debug.ts";
import { markerSpanAt, segmentAtomicImageMarkers } from "./marker-spans.ts";
import type { ClipboardPayload } from "./clipboard.ts";
import type { ImageContent } from "./content.ts";

interface EditorInternals {
	state: { lines: string[]; cursorLine: number; cursorCol: number };
	segment?: (text: string, mode?: "word" | "grapheme") => Iterable<Intl.SegmentData>;
	pushUndoSnapshot?: () => void;
	setCursorCol?: (col: number) => void;
	lastAction?: unknown;
	historyIndex?: number;
}

type AtomicEditorHost = EditorInternals & {
	handleInput(data: string): void;
	getCursor(): { line: number; col: number };
	getLines(): string[];
	getText(): string;
	insertTextAtCursor?(text: string): void;
	onSubmit?: (text: string) => void;
	onChange?: (text: string) => void;
	onPasteImage?: () => void;
};

type AtomicEditorOptions = {
	readClipboard: () => Promise<ClipboardPayload>;
	attachImage: (image: ImageContent) => string;
};

const ATOMIC_EDITOR_INSTALLED = Symbol.for("pi-image-view.atomic-editor-installed");
const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const wordSegmenter = new Intl.Segmenter(undefined, { granularity: "word" });

/**
 * Add image-view behavior to any Pi-compatible editor instance. This is an
 * instance decorator rather than a visual wrapper, so an existing editor such
 * as Zentui keeps ownership of rendering, status, focus, and callbacks.
 */
export function enhanceAtomicMarkerEditor<T extends object>(
	editor: T,
	tui: TUI,
	keys: KeybindingsManager,
	options: AtomicEditorOptions,
): T {
	const host = editor as T & AtomicEditorHost & { [ATOMIC_EDITOR_INSTALLED]?: true };
	if (host[ATOMIC_EDITOR_INSTALLED]) return editor;
	if (
		typeof host.handleInput !== "function" ||
		typeof host.getCursor !== "function" ||
		typeof host.getLines !== "function" ||
		typeof host.getText !== "function"
	) {
		debugLog("Atomic markers skipped: editor is missing a required method");
		return editor;
	}
	// Decorating a forwarding wrapper is unsafe in both directions. Its editing
	// state lives on the wrapped editor, and the instance accessors installed
	// below would shadow the wrapper's own forwarding accessors, so the host's
	// `onSubmit`/`onPasteImage` assignments would stop reaching the real editor.
	// Declining leaves the wrapper delegating to a base that this decorator has
	// usually already enhanced, which keeps every behavior working.
	if (!Object.hasOwn(host, "state") || !Array.isArray(host.state?.lines)) {
		debugLog("Atomic markers skipped: editor does not own its editing state");
		return editor;
	}

	Object.defineProperty(host, ATOMIC_EDITOR_INSTALLED, { value: true });
	host.segment = (text, mode = "grapheme") =>
		segmentAtomicImageMarkers(text, mode === "word" ? wordSegmenter : graphemeSegmenter);

	let draftGeneration = 0;
	let submitHandler = host.onSubmit;
	let fallbackPasteHandler = host.onPasteImage;
	let pasteQueue: Promise<void> = Promise.resolve();
	const originalHandleInput = host.handleInput.bind(host);

	const notifySubmit = (text: string): void => {
		draftGeneration += 1;
		submitHandler?.call(host, text);
	};
	Object.defineProperty(host, "onSubmit", {
		configurable: true,
		enumerable: true,
		get: () => (submitHandler ? notifySubmit : undefined),
		set: (handler: ((text: string) => void) | undefined) => { submitHandler = handler; },
	});

	const handleClipboardPaste = async (generation: number): Promise<void> => {
		let payload: ClipboardPayload;
		try {
			payload = await options.readClipboard();
		} catch {
			payload = { kind: "empty" };
		}
		if (generation !== draftGeneration) return;
		if (payload.kind === "empty" || typeof host.insertTextAtCursor !== "function") {
			fallbackPasteHandler?.call(host);
			return;
		}
		const text = payload.kind === "image" ? options.attachImage(payload.image) : payload.text;
		host.insertTextAtCursor(text);
		tui.requestRender();
	};
	const directPaste = (): void => {
		const generation = draftGeneration;
		pasteQueue = pasteQueue
			.then(() => handleClipboardPaste(generation))
			.catch((error) => debugLog("Clipboard paste failed", error));
	};
	Object.defineProperty(host, "onPasteImage", {
		configurable: true,
		enumerable: true,
		// Pi only assigns its default handler while this property is initially
		// falsy. Expose direct paste after that assignment and keep the assigned
		// handler as the path/text fallback for failed Linux reads.
		get: () => (fallbackPasteHandler ? directPaste : undefined),
		set: (handler: (() => void) | undefined) => {
			if (handler !== directPaste) fallbackPasteHandler = handler;
		},
	});

	const setCursor = (col: number): void => {
		if (host.setCursorCol) host.setCursorCol(col);
		else host.state.cursorCol = col;
	};
	const deleteRange = (lineIndex: number, start: number, end: number): boolean => {
		if (!host.pushUndoSnapshot) return false;
		host.pushUndoSnapshot();
		const line = host.state.lines[lineIndex] ?? "";
		host.state.lines[lineIndex] = line.slice(0, start) + line.slice(end);
		host.state.cursorLine = lineIndex;
		setCursor(start);
		host.lastAction = null;
		host.historyIndex = -1;
		host.onChange?.(host.getText());
		tui.requestRender();
		return true;
	};

	host.handleInput = (data: string): void => {
		const action = keys.matches(data, "tui.editor.cursorLeft") ? "left"
			: keys.matches(data, "tui.editor.cursorRight") ? "right"
				: keys.matches(data, "tui.editor.deleteCharBackward") ? "backspace"
					: keys.matches(data, "tui.editor.deleteCharForward") ? "delete"
						: undefined;
		if (!action) return originalHandleInput(data);
		const cursor = host.getCursor();
		const line = host.getLines()[cursor.line] ?? "";
		const span = markerSpanAt(line, cursor.col, action);
		if (!span) return originalHandleInput(data);
		if (action === "left" || action === "right") {
			setCursor(action === "left" ? span.start : span.end);
			tui.requestRender();
			return;
		}
		if (!deleteRange(cursor.line, span.start, span.end)) originalHandleInput(data);
	};

	return editor;
}

export class ImageViewAtomicEditor extends CustomEditor {
	constructor(
		tui: TUI,
		theme: EditorTheme,
		keys: KeybindingsManager,
		options: AtomicEditorOptions,
	) {
		super(tui, theme, keys);
		enhanceAtomicMarkerEditor(this, tui, keys, options);
	}
}

export function createAtomicMarkerEditor(
	tui: TUI,
	theme: EditorTheme,
	keys: KeybindingsManager,
	options: AtomicEditorOptions,
	baseEditor?: object,
) {
	return baseEditor
		? enhanceAtomicMarkerEditor(baseEditor, tui, keys, options)
		: new ImageViewAtomicEditor(tui, theme, keys, options);
}
