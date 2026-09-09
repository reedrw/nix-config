// Chat-style emoji picker for the pi editor.
//
// Typing ":" pops a fuzzy emoji search above the editor (a widget, the same
// slot pi renders extension widgets in — aboveEditor). Typing filters live;
// the search text stays in the editor. While the popup is open, Tab and Enter
// replace ":query" with the selected emoji (without submitting the message —
// the key is consumed before the editor sees it), Escape dismisses, and
// arrows up/down move the selection. Space inserts normally, breaks the
// ":query" match, and the popup closes.
//
// Input is observed via ctx.ui.onTerminalInput as a NON-CONSUMING listener:
// the TUI input loop returns on { consume: true } before its own
// requestImmediateRender, so any repaint we cause must be requested
// ourselves (tui.requestRender() from the deferred recompute). The popup
// therefore lives one setTimeout(0) behind keystrokes — invisible at
// typing speed, and it sees post-input editor state.
//
// Emoji data: emojilib (https://github.com/muan/emojilib), fetched at
// session start from unpkg's @latest dist file. The response's
// Last-Modified/ETag are cached alongside the compiled dataset and replayed
// as conditional-request headers, so steady-state sessions get a 304 and no
// re-parse. Offline or before the first successful fetch, a cached copy is
// used when present; with neither, the picker stays dormant (":" types
// normally).

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { Container, Text, matchesKey } from "@earendil-works/pi-tui";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionUIContext } from "@earendil-works/pi-coding-agent";

const EMOJI_URL = "https://unpkg.com/emojilib@latest/dist/emoji-en-US.json";
// Under the pi agent dir (honors its env overrides; persisted with ~/.pi on
// impermanence setups — ~/.cache is not).
const CACHE_PATH = join(getAgentDir(), "cache", "emoji-picker.json");
const MAX_ROWS = 7;
const WIDGET_KEY = "emoji-picker";

// [emoji, primary name (underscores → spaces), full search string]
type EmojiEntry = [string, string, string];

interface EmojiCache {
	// Bumped when the entry shape changes (v1: keyword array in slot 2; v2:
	// prebuilt search string). A mismatched version invalidates the data so
	// the next refresh refetches instead of misreading the old shape.
	version: 2;
	lastModified?: string;
	etag?: string;
	data: EmojiEntry[];
}

// The dataset must survive /reload and session re-binds (module instances are
// per-bind; globalThis is shared — see the pi-ui skill).
const store = globalThis as typeof globalThis & {
	__piEmojiPickerData?: EmojiEntry[];
	__piEmojiPickerFetching?: boolean;
};

// ── Editor access ────────────────────────────────────────────────────────────

// Captured from the zero-content widget factory at session_start — the only
// sanctioned way for an extension to reach the live TUI. The widget stays
// installed rendering an empty Container (indistinguishable from no widget:
// the dock adds the same leading Spacer either way) and doubles as the popup
// surface once activated.
let tui: unknown = undefined;

interface EditorLike {
	getText(): string;
	setText(text: string): void;
	getCursor(): { line: number; col: number };
}

function editorOf(): EditorLike | null {
	const focused = (tui as { getFocusedComponent?(): unknown } | undefined)?.getFocusedComponent?.();
	if (!focused || typeof focused !== "object") return null;
	const e = focused as Partial<EditorLike>;
	if (typeof e.getText !== "function" || typeof e.setText !== "function" || typeof e.getCursor !== "function") {
		return null;
	}
	return focused as EditorLike;
}

// pi-tui's Editor keeps cursor state in plain fields; only getCursor() is
// public. Repositioning after an emoji insertion pokes the state directly.
function setCursor(editor: EditorLike, line: number, col: number): void {
	const state = (editor as { state?: { lines: string[]; cursorLine: number; cursorCol: number } }).state;
	if (!state || line < 0 || line >= state.lines.length) return;
	state.cursorLine = line;
	state.cursorCol = Math.min(Math.max(col, 0), state.lines[line]?.length ?? 0);
}

function requestRender(): void {
	const t = tui as { requestRender?(force?: boolean): void } | undefined;
	t?.requestRender?.();
}

// ── Emoji data ───────────────────────────────────────────────────────────────

// emojilib shape: { "😀": ["grinning_face", "face", "smile", ...] }
function compactFromRaw(raw: unknown): EmojiEntry[] {
	const out: EmojiEntry[] = [];
	if (typeof raw !== "object" || raw === null) return out;
	for (const [emoji, kws] of Object.entries(raw as Record<string, unknown>)) {
		if (!Array.isArray(kws) || kws.length === 0) continue;
		const words = kws
			.filter((k): k is string => typeof k === "string" && k.length > 0)
			.map((k) => k.toLowerCase().replace(/_/g, " "));
		if (words.length === 0) continue;
		out.push([emoji, words[0], words.join(" ")]);
	}
	return out;
}

function readCache(): EmojiCache | undefined {
	try {
		const parsed = JSON.parse(readFileSync(CACHE_PATH, "utf8")) as Partial<EmojiCache>;
		if (parsed.version !== 2 || !Array.isArray(parsed.data)) return undefined;
		return {
			version: 2,
			lastModified: parsed.lastModified,
			etag: parsed.etag,
			data: parsed.data as EmojiEntry[],
		};
	} catch {
		return undefined;
	}
}

function writeCache(cache: EmojiCache): void {
	try {
		mkdirSync(dirname(CACHE_PATH), { recursive: true });
		writeFileSync(CACHE_PATH, JSON.stringify(cache));
	} catch {
		// Cache is best-effort; the picker works without it.
	}
}

async function refreshData(): Promise<void> {
	if (store.__piEmojiPickerFetching) return;
	store.__piEmojiPickerFetching = true;
	try {
		const cached = readCache();
		const headers: Record<string, string> = {};
		if (cached?.etag) headers["if-none-match"] = cached.etag;
		if (cached?.lastModified) headers["if-modified-since"] = cached.lastModified;
		const res = await fetch(EMOJI_URL, { headers });
		if (res.status === 304 && cached) return; // cache is current
		if (!res.ok) return;
		const data = compactFromRaw(await res.json());
		if (data.length === 0) return;
		store.__piEmojiPickerData = data;
		writeCache({
			version: 2,
			lastModified: res.headers.get("last-modified") ?? undefined,
			etag: res.headers.get("etag") ?? undefined,
			data,
		});
	} catch {
		// Offline / unpkg unreachable: keep whatever we already have.
	} finally {
		store.__piEmojiPickerFetching = false;
	}
}

// ── Matching ─────────────────────────────────────────────────────────────────

// wofi-emoji feeds wofi one "emoji name keywords…" line per emoji and lets
// its dmenu filter do case-insensitive substring matching, preserving
// dataset order — and the dataset is emojilib's canonical, category-grouped
// order. Same here: every query token must appear as a substring of the
// entry's search string (name + keywords, lowercased, underscores → spaces);
// matches keep emojilib order, no scoring. So "smile" lists the smileys in
// familiar picker order instead of ranking an obscure exact-keyword match
// above them.
function searchEntries(entries: EmojiEntry[], query: string): EmojiEntry[] {
	if (query === "") return entries.slice(0, MAX_ROWS);
	const tokens = query.split(/[\s/]+/).filter((t) => t.length > 0);
	if (tokens.length === 0) return entries.slice(0, MAX_ROWS);
	const out: EmojiEntry[] = [];
	for (const entry of entries) {
		if (tokens.every((t) => entry[2].includes(t))) {
			out.push(entry);
			if (out.length === MAX_ROWS) break;
		}
	}
	return out;
}

// ── Popup state & widget ─────────────────────────────────────────────────────

interface PopupState {
	line: number;
	startCol: number; // index of the ":" in the line
	query: string;
	items: EmojiEntry[];
	sel: number;
}

let popup: PopupState | null = null;
// Set by Escape; keyed by "line:startCol:query" so the next edit re-opens.
let suppressed: string | null = null;
// True while the widget slot holds a popup; guards against redundant
// setWidget(undefined) calls (each one triggers a full widget re-render).
let widgetVisible = false;

// UI context captured at session_start; every key handler runs after that.
let ui: ExtensionUIContext | undefined;

function clearWidget(): void {
	if (!widgetVisible) return;
	widgetVisible = false;
	ui?.setWidget(WIDGET_KEY, undefined);
}

function hide(): void {
	if (popup === null && suppressed === null) return;
	popup = null;
	clearWidget();
}

// Close without the suppressed-key bookkeeping (Tab/Enter confirmed an emoji;
// the ":query" token is gone from the editor, so nothing to suppress).
function closePopup(): void {
	popup = null;
	suppressed = null;
	clearWidget();
}

function render(): void {
	if (!popup || !ui) return;
	widgetVisible = true;
	const { query, items, sel } = popup;
	const tokens = query.split(/[\s/]+/).filter((t) => t.length > 0);
	// The factory runs synchronously inside setWidget, receiving the TUI
	// (already captured) and the live theme. A single Text keeps the widget
	// comfortably under pi's 10-line cap (header + MAX_ROWS rows).
	ui.setWidget(WIDGET_KEY, (_t, theme) => {
		const lines: string[] = [theme.fg("accent", `:${query}`)];
		for (let i = 0; i < items.length; i++) {
			const marker = items.length > 1 ? (i === sel ? "▸ " : "  ") : "";
			const text = `${marker}${styledEntry(items[i], tokens, theme)}`;
			lines.push(i === sel && items.length > 1 ? theme.fg("accent", text) : text);
		}
		return new Text(lines.join("\n"), 1, 0);
	});
}

interface ThemeLike {
	fg(token: "text" | "dim", text: string): string;
	bold(text: string): string;
}

// "😀 name kw1 kw2 …" — keywords dimmed, the substring a query token matched
// rendered bold. Highlighting is per-token on the displayed text (the same
// substring test searchEntries used); earliest token match wins.
function styledEntry(entry: EmojiEntry, tokens: string[], theme: ThemeLike): string {
	const [emoji, name, search] = entry;
	const keywords = name.length < search.length ? search.slice(name.length + 1) : "";
	let out = `${emoji} ${highlight(name, tokens, theme, "text")}`;
	if (keywords) out += ` ${highlight(keywords, tokens, theme, "dim")}`;
	return out;
}

function highlight(text: string, tokens: string[], theme: ThemeLike, color: "text" | "dim"): string {
	if (tokens.length === 0) return theme.fg(color, text);
	const lower = text.toLowerCase();
	let start = -1;
	let end = -1;
	for (const token of tokens) {
		const i = lower.indexOf(token);
		if (i !== -1 && (start === -1 || i < start)) {
			start = i;
			end = i + token.length;
		}
	}
	if (start === -1) return theme.fg(color, text);
	return (
		theme.fg(color, text.slice(0, start)) +
		theme.bold(theme.fg(color, text.slice(start, end))) +
		theme.fg(color, text.slice(end))
	);
}

// ── Recompute (deferred; sees post-keystroke editor state) ───────────────────

let recomputeTimer: ReturnType<typeof setTimeout> | undefined;

function scheduleRecompute(): void {
	clearTimeout(recomputeTimer);
	recomputeTimer = setTimeout(() => {
		const editor = editorOf();
		if (!editor) {
			hide();
			return;
		}
		const data = store.__piEmojiPickerData;
		if (!data) {
			hide();
			return;
		}

		const cursor = editor.getCursor();
		const line = editor.getText().split("\n")[cursor.line] ?? "";
		const before = line.slice(0, cursor.col);

		// Token start: ":" at start of text, after whitespace — or, to allow
		// consecutive picks ("😎" then ":" again), after any non-word character
		// (the guard keeps "http:" and "time:5" from triggering).
		let startCol: number;
		let query: string;
		const m = /(?:^|\s):([\w+-]*)$/.exec(before);
		if (m) {
			startCol = cursor.col - (m[1]?.length ?? 0) - 1;
			query = (m[1] ?? "").toLowerCase();
		} else {
			const idx = before.lastIndexOf(":");
			const rest = idx >= 0 ? before.slice(idx + 1) : "";
			const prev = idx > 0 ? (before[idx - 1] ?? "") : undefined;
			if (idx <= 0 || (prev !== undefined && /[\w:]/.test(prev)) || !/^[\w+-]*$/.test(rest)) {
				hide();
				return;
			}
			startCol = idx;
			query = rest.toLowerCase();
		}

		const key = `${cursor.line}:${startCol}:${query}`;

		if (suppressed === key) {
			hide();
			return;
		}

		// New token (or the caret reached a different one): re-search and reset
		// the selection.
		if (!popup || popup.line !== cursor.line || popup.startCol !== startCol || popup.query !== query) {
			const items = searchEntries(data, query);
			if (items.length === 0) {
				hide();
				return;
			}
			popup = { line: cursor.line, startCol, query, items, sel: 0 };
			suppressed = null;
		}

		render();
	}, 0);
}

// ── Actions ──────────────────────────────────────────────────────────────────

function applySelection(editor: EditorLike): void {
	const state = popup;
	closePopup();
	if (!state) return;
	const entry = state.items[state.sel];
	if (!entry) return;

	const cursor = editor.getCursor();
	const lines = editor.getText().split("\n");
	const line = lines[cursor.line] ?? "";
	lines[cursor.line] = line.slice(0, state.startCol) + entry[0] + line.slice(cursor.col);
	editor.setText(lines.join("\n"));
	// setText leaves the cursor at end-of-text; restore it just past the emoji.
	setCursor(editor, cursor.line, state.startCol + entry[0].length);
}

// ── Key handling ─────────────────────────────────────────────────────────────

function handleInput(data: string): { consume?: boolean } | undefined {
	const editor = editorOf();
	if (!editor) {
		// A dialog/selector owns the focus; the token state is stale either way.
		hide();
		return;
	}

	if (popup) {
		// Tab and Enter confirm the selected emoji. Consuming the key before the
		// editor sees it is what keeps Enter from submitting the message.
		// matchesKey because pi negotiates the kitty keyboard protocol — these
		// keys arrive as CSI-u sequences, not raw bytes.
		if (matchesKey(data, "tab") || matchesKey(data, "enter")) {
			applySelection(editor);
			// Consumed input skips pi's post-keypress render; we changed the
			// editor text and cleared the widget, so render ourselves.
			requestRender();
			return { consume: true };
		}
		if (matchesKey(data, "escape")) {
			suppressed = `${popup.line}:${popup.startCol}:${popup.query}`;
			popup = null;
			clearWidget();
			requestRender();
			return { consume: true };
		}
		if (matchesKey(data, "up") || matchesKey(data, "down")) {
			const down = matchesKey(data, "down");
			const n = popup.items.length;
			if (n > 1) {
				popup.sel = (popup.sel + (down ? 1 : n - 1)) % n;
				render();
				requestRender();
			}
			return { consume: true };
		}
	}

	// Observer: never consume; let the editor insert, then re-evaluate.
	scheduleRecompute();
	return;
}

// ── Extension entry ──────────────────────────────────────────────────────────

export default function emojiPickerExtension(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Data: use the cache immediately if present; refresh from unpkg in the
		// background (conditional request — 304 keeps the cache, 200 replaces).
		if (!store.__piEmojiPickerData) {
			store.__piEmojiPickerData = readCache()?.data;
		}
		void refreshData();

		// Capture the TUI + UI context from a zero-content widget factory (runs
		// synchronously inside setWidget). The empty Container renders zero
		// lines — identical to no widget — but the widget slot is now ours to
		// fill when the popup activates.
		ui = ctx.ui;
		ctx.ui.setWidget(WIDGET_KEY, (t) => {
			tui = t;
			return new Container();
		});
		ctx.ui.onTerminalInput(handleInput);
	});
}
