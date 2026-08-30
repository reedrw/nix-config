// claude-style: Claude Code inspired tool rendering for pi.
//
// One-line tool calls (`● Bash <cmd>`), one-line result summaries
// (`⎿  42 lines`), no boxes. Full output on demand via ctrl+o (the expanded
// flag pi already manages).
//
// This is a *library* module, not an auto-discovered extension: pi only
// auto-loads `extensions/*.ts` and `extensions/*/index.ts`, so files under
// `lib/` are inert on their own. Tool-name ownership is split across
// extensions (nix-comma.ts owns `bash`, image-history.ts owns `read`,
// claude-style-ui.ts owns the rest), and each imports its slots from here.
//
// Self-shell mode (`renderShell: "self"`) drops pi's padded tool Box so rows
// stack tightly, Claude Code style.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Container, Text } from "@earendil-works/pi-tui";
import type { Component } from "@earendil-works/pi-tui";
import { keyText } from "@earendil-works/pi-coding-agent";
import type { Theme } from "@earendil-works/pi-coding-agent";

// Max width of a one-line call/summary before ellipsis. Terminal-width-aware
// wrapping is left to Text for expanded output; single-line slots are capped
// hard so parallel tool batches stay scannable.
const MAX_LINE = 120;
// Cap for expanded diff output; bash etc. rely on pi's upstream truncation.
const MAX_EXPANDED_DIFF_LINES = 400;

// Global style toggle: `claudeStyle: false` in .pi/settings.json (project)
// or ~/.pi/agent/settings.json (global; project wins) keeps pi's default
// rendering. Checked when extensions register their render slots, so a
// toggle needs a restart or /reload to take effect.
export function claudeStyleEnabled(): boolean {
	for (const path of [
		join(process.cwd(), ".pi", "settings.json"),
		join(homedir(), ".pi", "agent", "settings.json"),
	]) {
		try {
			const settings = JSON.parse(readFileSync(path, "utf8")) as { claudeStyle?: unknown };
			if (typeof settings.claudeStyle === "boolean") return settings.claudeStyle;
		} catch {
			// Missing or unparsable — fall through to the next scope.
		}
	}
	return true;
}

type RenderSlots = {
	renderShell: "self";
	renderCall: (args: any, theme: Theme, context: any) => Component;
	renderResult: (result: any, options: any, theme: Theme, context: any) => Component;
};

function shortenPath(path: string): string {
	const home = homedir();
	return path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

function clip(text: string, max = MAX_LINE): string {
	const line = text.replace(/\s+/g, " ").trim();
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

function firstLine(text: string): string {
	for (const line of text.split("\n")) {
		if (line.trim()) return line;
	}
	return "";
}

function lastLine(text: string): string {
	return firstLine(text.split("\n").reverse().join("\n"));
}

// `● label arg` — the call row. Status dot: grey while pending/running, then
// red on error / green on success. The call slot doesn't re-render by itself
// once the call settles, so the status is kept in context.state (shared
// across the row's slots) and written by settleStatus() from renderResult,
// which invalidates the row to repaint the dot. Claude Code style call:
// bold label with the argument inside parentheses.
function statusDot(theme: Theme, context: any): string {
	const status = context?.state?.status;
	if (status === "error") return theme.fg("error", "●");
	if (status === "success") return theme.fg("success", "●");
	return theme.fg("muted", "●");
}

// Record the final status of a tool row and request a repaint so the call
// slot's dot picks it up. Only invalidates on change — renderResult runs on
// every row render, and an unconditional invalidate would loop forever. The
// invalidate must be deferred: calling it synchronously from inside
// renderResult re-enters the row's updateDisplay() mid-rebuild, and the
// aborted outer pass appends its components again — duplicating every line.
export function settleStatus(context: any, error: boolean): void {
	const status = error ? "error" : "success";
	if (context?.state && context.state.status !== status) {
		context.state.status = status;
		setTimeout(() => context.invalidate(), 0);
	}
}

function callLine(label: string, arg: string, theme: Theme, suffix = "", context?: any): Text {
	const mode = context ? groupMode(context?.toolCallId) : undefined;
	// A row that opens its batch (solo or expanded-latest) has no group header
	// to carry the leading blank line, so it brings its own.
	const lead = mode?.kind === "latest" && mode.first ? "\n" : "";
	const body = arg
		? `${theme.fg("toolTitle", "(")}${theme.fg("accent", clip(arg))}${theme.fg("toolTitle", ")")}`
		: "";
	return new Text(`${lead}${statusDot(theme, context)} ${theme.fg("toolTitle", theme.bold(label))}${body}${suffix}`, 0, 0);
}

// `⎿  summary` — the result row, indented under the call. Muted connector,
// muted summary on success (dim is too dark against most themes), red on error.
function resultLine(theme: Theme, summary: string, error = false): Text {
	const body = error ? theme.fg("error", summary) : theme.fg("muted", summary);
	return new Text(`  ${theme.fg("muted", "⎿")}  ${body}`, 0, 0);
}

// Expanded output block: the first line rides the ⎿ connector and the rest
// are indented to the same column, so the whole block lines up.
const GLANCE_INDENT = "     "; // width of `  ⎿  `
// Lines of output shown while a bash command streams.
const LIVE_OUTPUT_LINES = 20;

// Live output while a command streams: tail-capped, aligned like the expanded
// view, with a muted marker when older lines are trimmed.
function liveStream(text: string, theme: Theme): Text {
	const lines = text.split("\n").filter((l) => l.trim());
	const tail = lines.slice(-LIVE_OUTPUT_LINES);
	let out = `  ${theme.fg("muted", "⎿")}  ${theme.fg("toolOutput", tail[0] ?? "")}`;
	if (tail.length > 1) {
		out += "\n" + tail.slice(1).map((l) => GLANCE_INDENT + theme.fg("toolOutput", l)).join("\n");
	}
	if (lines.length > LIVE_OUTPUT_LINES) {
		out = `  ${theme.fg("muted", "⎿  …")}\n` + out;
	}
	return new Text(out, 0, 0);
}
// Head-only preview for the auto-expanded "latest" row: long outputs are
// pinned to a fixed height so the screen doesn't jump while the agent works.
// Deliberate ctrl+o expansion lifts the cap entirely.
const LATEST_EXPANDED_LINES = 16;

export function latestCap(mode: GroupMode, expanded: boolean | undefined): number | undefined {
	return mode.kind === "latest" && !expanded ? LATEST_EXPANDED_LINES : undefined;
}

function capLines(lines: string[], cap: number | undefined, theme: Theme): string[] {
	if (cap === undefined || lines.length <= cap) return lines;
	const rest = lines.length - cap;
	return [...lines.slice(0, cap), theme.fg("muted", `… +${rest} more lines (${keyText("app.tools.expand")} to expand)`)];
}

function expandedBlock(text: string, theme: Theme, error = false, cap?: number): Text {
	const color = error ? "error" : "toolOutput";
	const lines = capLines(text.split("\n"), cap, theme);
	let out = `  ${theme.fg("muted", "⎿")}  ${theme.fg(color, lines[0] ?? "")}`;
	if (lines.length > 1) {
		out += "\n" + lines.slice(1).map((l) => GLANCE_INDENT + theme.fg(color, l)).join("\n");
	}
	return new Text(out, 0, 0);
}

function resultText(result: any, excludeMarker?: string): string {
	return (result?.content ?? [])
		.filter(
			(c: any) =>
				c.type === "text" &&
				!(excludeMarker && typeof c.text === "string" && c.text.trimStart().startsWith(excludeMarker)),
		)
		.map((c: any) => c.text)
		.join("\n");
}

function truncationNote(details: any, theme: Theme): string {
	if (!details?.truncation?.truncated) return "";
	return theme.fg("warning", " [truncated]");
}

function withMore(text: string, cap: number, theme: Theme): string {
	const lines = text.split("\n");
	if (lines.length <= cap) return text;
	return lines.slice(0, cap).join("\n") + theme.fg("muted", `\n… (${lines.length - cap} more lines)`);
}

// ---------------------------------------------------------------------------
// ── Tool call grouping ─────────────────────────
//
// Claude Code style batching: consecutive tool calls form a batch. While the
// batch is the latest activity, its newest call renders expanded and earlier
// members render as one-line glance rows. Reasoning folds the batch visually
// (header + glance rows appear immediately) without closing it; visible
// assistant text, a user message, or the end of the response closes it under
// the final `✻ Thought for Xs · Ran N tool calls` header. Per-row ctrl+o
// expansion always overrides the grouping.
//
// State lives on globalThis: this lib module is imported by several
// independent extensions (nix-comma.ts, image-history.ts, claude-style-ui.ts)
// which may each get their own module instance. claude-style-ui.ts registers
// the event handlers; the renderers in every extension read the shared state.

interface ToolBatch {
	ids: string[];
	collapsed: boolean;
	// Visual fold while reasoning streams after this batch's tools: render
	// header + glance rows, but keep the batch open for more tool calls.
	folded?: boolean;
	// timestamps of the assistant messages whose thinking fed this batch;
	// durations are looked up per key (published by the pi-thinking-fold
	// fork) and summed for the header.
	thoughtKeys: number[];
}

interface GroupState {
	counter: number;
	notes: Map<string, string[]>;
	order: Map<string, number>;
	memberBatch: Map<string, number>;
	batches: ToolBatch[];
	current: number | undefined;
	latest: string | undefined;
	// Per-row invalidate callbacks, registered by renderers, so state changes
	// (batch collapse, newer latest) can force the affected rows to re-render —
	// tool rows render cached children otherwise.
	invalidators: Map<string, () => void>;
}

const GROUP_STATE_KEY = "__piClaudeStyleToolGroups";

function freshGroupState(): GroupState {
	return {
		counter: 0,
		order: new Map(),
		memberBatch: new Map(),
		batches: [],
		current: undefined,
		latest: undefined,
		invalidators: new Map(),
		notes: new Map(),
	};
}

// Remember how to force a tool row to re-render. Called from render slots.
function trackRow(context: any): void {
	if (context?.toolCallId && typeof context.invalidate === "function") {
		groupState().invalidators.set(context.toolCallId, context.invalidate);
	}
}

// Defer row invalidations out of the current call stack — invalidate() from
// inside a render pass re-enters the row's updateDisplay() mid-rebuild and
// duplicates its components (same bug settleStatus works around).
function invalidateRows(ids: Iterable<string>): void {
	const s = groupState();
	for (const id of ids) {
		const invalidate = s.invalidators.get(id);
		if (invalidate) setTimeout(invalidate, 0);
	}
}

function groupState(): GroupState {
	const w = globalThis as Record<string, unknown>;
	if (!w[GROUP_STATE_KEY]) w[GROUP_STATE_KEY] = freshGroupState();
	return w[GROUP_STATE_KEY] as GroupState;
}

export function trackGroupToolCall(toolCallId: string, thoughtKey?: number): void {
	const s = groupState();
	s.order.set(toolCallId, ++s.counter);
	if (s.current === undefined) {
		s.batches.push({ ids: [], collapsed: false, thoughtKeys: thoughtKey === undefined ? [] : [thoughtKey] });
		s.current = s.batches.length - 1;
	} else if (thoughtKey !== undefined && !s.batches[s.current].thoughtKeys.includes(thoughtKey)) {
		s.batches[s.current].thoughtKeys.push(thoughtKey);
	}
	s.batches[s.current].ids.push(toolCallId);
	s.memberBatch.set(toolCallId, s.current);
	const previousLatest = s.latest;
	s.latest = toolCallId;
	// The previously-latest row drops from expanded to glance rendering, and
	// the batch's first row updates its live `✻ Ran N tool calls` count.
	if (previousLatest && previousLatest !== toolCallId) {
		const first = s.batches[s.current].ids[0];
		invalidateRows(new Set([previousLatest, first]));
	}
}

// Visual fold when reasoning starts while a batch is open: the header (with
// the accumulated thought duration) appears above the glance rows right away,
// but unlike collapseToolGroup the batch stays current — later tool calls
// still merge into it.
export function foldToolGroup(): void {
	const s = groupState();
	if (s.current === undefined) return;
	const batch = s.batches[s.current];
	if (batch.folded || batch.collapsed) return;
	batch.folded = true;
	invalidateRows(batch.ids);
}

export function collapseToolGroup(): void {
	const s = groupState();
	if (s.current !== undefined) {
		const batch = s.batches[s.current];
		batch.collapsed = true;
		// Every member re-renders: the first row gains the batch header, the
		// rest fold to glance lines, and the latest drops its expanded output.
		invalidateRows(batch.ids);
		s.current = undefined;
	}
	s.latest = undefined;
}

// Fold an extension notification into the open batch as a note line under
// its latest tool row. Returns false when there is no open batch — the caller
// (the patched showExtensionNotify) then falls back to pi's native rendering.
export function pushToolNote(text: string): boolean {
	const s = groupState();
	if (s.current === undefined || !s.latest) return false;
	const list = s.notes.get(s.latest) ?? [];
	list.push(text);
	s.notes.set(s.latest, list);
	invalidateRows([s.latest]);
	return true;
}

// Append a row's accumulated notes (dim, glance-indented) under its result.
export function attachNotes(component: Component, context: any, theme: Theme): Component {
	const id = context?.toolCallId;
	const notes = id ? groupState().notes.get(id) : undefined;
	if (!notes || notes.length === 0) return component;
	const stack = new Container();
	stack.addChild(component);
	for (const note of notes) {
		stack.addChild(new Text(`  ${theme.fg("muted", "⎿")}  ${theme.italic(theme.fg("dim", clip(note, 90)))}`, 0, 0));
	}
	return stack;
}

// Wrap a slot set so notes pushed while its result renders appear under it.
export function withToolNotes<T extends RenderSlots>(slots: T): T {
	const { renderResult, ...rest } = slots;
	if (!renderResult) return slots;
	return {
		...rest,
		renderResult(result: any, options: any, theme: Theme, context: any): Component {
			return attachNotes(renderResult.call(this, result, options, theme, context), context, theme);
		},
	} as T;
}

export function resetToolGroups(): void {
	(globalThis as Record<string, unknown>)[GROUP_STATE_KEY] = freshGroupState();
}

export function scanToolGroupsFromHistory(entries: Iterable<{ type: string; message?: unknown }>): void {
	resetToolGroups();
	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const message = entry.message as { role?: unknown; content?: unknown } | undefined;
		if (!message) continue;
		if (message.role === "user") {
			collapseToolGroup();
		} else if (message.role === "assistant") {
			// Mirror the live rule: visible assistant text splits the batch;
			// thinking folds into it, and bare tool-carrier messages (silent
			// retries) join the current batch.
			const hasVisible = Array.isArray(message.content) &&
				message.content.some(
					(part) =>
						part !== null && typeof part === "object" &&
						(part as { type?: unknown }).type === "text" &&
						typeof (part as { text?: unknown }).text === "string" &&
						((part as { text: string }).text).trim().length > 0,
				);
			if (hasVisible) collapseToolGroup();
			const hasThinking = Array.isArray(message.content) &&
				message.content.some(
					(part) =>
						part !== null && typeof part === "object" &&
						(part as { type?: unknown }).type === "thinking",
				);
			const thoughtKey = hasThinking && typeof (message as { timestamp?: unknown }).timestamp === "number"
				? (message as { timestamp: number }).timestamp
				: undefined;
			if (Array.isArray(message.content)) {
				for (const part of message.content) {
					if (
						part !== null && typeof part === "object" &&
						(part as { type?: unknown }).type === "toolCall" &&
						typeof (part as { id?: unknown }).id === "string"
					) {
						trackGroupToolCall((part as { id: string }).id, thoughtKey);
					}
				}
			}
		}
	}
}

export type GroupMode =
	| { kind: "normal" }
	| { kind: "latest"; first: boolean }
	| { kind: "earlier"; header: boolean; count: number; thoughtKeys?: number[] }
	| { kind: "collapsed"; header: boolean; count: number; thoughtKeys?: number[] };

function batchHeader(batch: ToolBatch, toolCallId: string): boolean {
	return batch.ids[0] === toolCallId;
}

export function groupMode(toolCallId: string | undefined | null): GroupMode {
	if (!toolCallId) return { kind: "normal" };
	const s = groupState();
	const idx = s.memberBatch.get(toolCallId);
	if (idx === undefined) return { kind: "normal" };
	const batch = s.batches[idx];
	if (batch.collapsed || batch.folded) {
		return {
			kind: "collapsed",
			header: batchHeader(batch, toolCallId),
			count: batch.ids.length,
			thoughtKeys: batch.thoughtKeys,
		};
	}
	if (s.latest === toolCallId) {
		return { kind: "latest", first: batch.ids[0] === toolCallId };
	}
	return {
		kind: "earlier",
		header: batchHeader(batch, toolCallId),
		count: batch.ids.length,
		thoughtKeys: batch.thoughtKeys,
	};
}

// Thinking durations are published by the pi-thinking-fold fork (live while
// streaming and reconstructed from message timestamps on session restore).
const THOUGHT_FOR_KEY = "__piClaudeStyleThoughtFor";
const THOUGHT_LIVE_KEY = "__piClaudeStyleThoughtLive";
const LIVE_THOUGHT_KEY = "__piClaudeStyleLiveThought";

interface LiveTiming {
	startedAt: number;
	completedAt?: number;
}

// Batch duration: completed thinking of every member message (live map
// preferred — it also carries in-progress entries), plus the elapsed time of
// a reasoning block currently streaming for a message that hasn't joined the
// batch yet. Sub-half-second totals are noise, not a phase worth naming.
function thoughtForMs(keys: number[] | undefined): number | undefined {
	const w = globalThis as Record<string, unknown>;
	const liveMap = w[THOUGHT_LIVE_KEY] as Map<number, LiveTiming> | undefined;
	const doneMap = w[THOUGHT_FOR_KEY] as Map<number, number> | undefined;
	let total = 0;
	for (const key of keys ?? []) {
		const lt = liveMap?.get(key);
		if (lt) total += Math.max(0, (lt.completedAt ?? Date.now()) - lt.startedAt);
		else {
			const ms = doneMap?.get(key);
			if (typeof ms === "number") total += ms;
		}
	}
	const liveKey = w[LIVE_THOUGHT_KEY];
	if (typeof liveKey === "number" && !keys?.includes(liveKey)) {
		const lt = liveMap?.get(liveKey);
		if (lt) total += Math.max(0, (lt.completedAt ?? Date.now()) - lt.startedAt);
	}
	return total >= 500 ? total : undefined;
}

// Called on a timer while reasoning streams: re-renders the folded batch so
// its header duration counts up. Returns false when there is nothing to tick
// (no open folded batch), letting the caller stop its timer.
export function tickFoldedBatch(): boolean {
	const s = groupState();
	if (s.current === undefined) return false;
	const batch = s.batches[s.current];
	if (!batch.folded || batch.collapsed) return false;
	invalidateRows(batch.ids);
	return true;
}

function formatThought(ms: number): string {
	const s = ms / 1000;
	if (s < 60) return `${s.toFixed(1)}s`;
	return `${Math.floor(s / 60)}m ${Math.round(s % 60)}s`;
}

export function groupHeaderLine(theme: Theme, count: number, thoughtMs?: number): string {
	// Full ANSI yellow (33 — same as the statusline git segment), italic label.
	const label = `Ran ${count} tool call${count === 1 ? " " : "s"}`;
	const thought = thoughtMs === undefined ? "" : `Thought for ${formatThought(thoughtMs)} · `;
	return `\x1b[33m✻ ${theme.italic(`${thought}${label} (${keyText("app.tools.expand")} to expand)`)}\x1b[0m`;
}

// ── Terminal theme (base16) colors ────────────────────────────
//
// home-modules/extra/ai/pi/default.nix renders the stylix base16 scheme to
// ~/.pi/agent/extensions/lib/base16.json, so TUI colors here can follow the
// terminal theme instead of being hardcoded. Read once per process and
// cached on globalThis (this lib is loaded by several independent extension
// module instances); a missing/unreadable file falls back to the Ayu Dark
// defaults.
const BASE16_PATH = join(homedir(), ".pi/agent/extensions/lib/base16.json");
const base16State = globalThis as Record<string, unknown>;

function base16(name: string): string | undefined {
	if (typeof base16State.__piClaudeStyleBase16 === "undefined") {
		try {
			base16State.__piClaudeStyleBase16 = JSON.parse(readFileSync(BASE16_PATH, "utf8"));
		} catch {
			base16State.__piClaudeStyleBase16 = {};
		}
	}
	const palette = base16State.__piClaudeStyleBase16 as Record<string, string>;
	return palette[name];
}

// Truecolor SGR foreground for a base16 color (hex without '#'); falls back
// to `fallbackHex` when the palette is unavailable.
function base16Fg(name: string, fallbackHex: string): string {
	let hex = base16(name);
	if (typeof hex !== "string" || !/^[0-9a-f]{6}$/i.test(hex)) hex = fallbackHex;
	const n = parseInt(hex, 16);
	return `\x1b[38;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
}

// Truecolor SGR background for a base16 color (hex without '#'); falls back
// to `fallbackHex` when the palette is unavailable.
export function base16Bg(name: string, fallbackHex: string): string {
	let hex = base16(name);
	if (typeof hex !== "string" || !/^[0-9a-f]{6}$/i.test(hex)) hex = fallbackHex;
	const n = parseInt(hex, 16);
	return `\x1b[48;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
}

// One-line collapsed representation: `⎿ Bash(cmd) · 51 lines`. The call
// head recedes to base03 (comments grey, from the base16 palette) so color
// is reserved for signal — exit codes, diffs, and pre-colored summaries.
// Expanded/most-recent call lines keep their normal theme colors via
// callLine.
export function glanceLine(label: string, arg: string, summary: string, theme: Theme): Text {
	const base03 = base16Fg("base03", "3e4b59");
	const head = `${base03}${label}(${clip(arg, 56)})\x1b[39m`;
	return new Text(`  ${theme.fg("muted", "⎿")}  ${head} · ${summary}`, 0, 0);
}

// True when the row should render as a single glance line: a non-latest
// member of a tool batch whose grouping isn't overridden by ctrl+o.
function glance(context: any): boolean {
	const mode = groupMode(context?.toolCallId);
	return (mode.kind === "collapsed" || mode.kind === "earlier") && !context?.expanded;
}

// Call slot for a grouped row: glance rows are empty (or carry the batch
// header on the first member, live while the batch runs and after collapse);
// otherwise undefined (= render normally).
function groupedCall(mode: GroupMode, expanded: boolean | undefined, theme: Theme): Component | undefined {
	if ((mode.kind === "collapsed" || mode.kind === "earlier") && !expanded) {
		if (mode.header) {
			// Leading blank line so groups stand apart from preceding content.
			const thoughtMs = thoughtForMs(mode.thoughtKeys);
			return new Text(`\n${groupHeaderLine(theme, mode.count, thoughtMs)}`, 0, 0);
		}
		// No visible content — an empty Container renders zero lines, whereas an
		// empty Text would leave a blank line between glance rows.
		return new Container();
	}
	return undefined;
}

// ---------------------------------------------------------------------------
// bash — success collapses to the first output line; errors collapse to the
// exit code plus the last output line (where the useful part usually is).
// Pi appends "Command exited with code N" to the output text of failed runs.
// ---------------------------------------------------------------------------

export const bash: RenderSlots = withToolNotes({
	renderShell: "self",
	renderCall(args, theme, context) {
		trackRow(context);
		const mode = groupMode(context?.toolCallId);
		const grouped = groupedCall(mode, context?.expanded, theme);
		if (grouped) return grouped;
		const timeout = args.timeout ? theme.fg("muted", ` (timeout ${args.timeout}s)`) : "";
		return callLine("Bash", args.command ?? "", theme, timeout, context);
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		const expandedNow = expanded || mode.kind === "latest";
		const text = resultText(result);
		if (isPartial && !context.isError) {
			if (glance(context)) {
				const live = lastLine(text);
				return resultLine(theme, live ? `Running… ${clip(live, 80)}` : "Running…");
			}
			return liveStream(text, theme);
		}
		settleStatus(context, context.isError);
		if (glance(context)) {
			const lineCount = text.split("\n").filter((l) => l.trim()).length;
			const exit = text.match(/Command exited with code (\d+)/);
			const summary = context.isError
				? theme.fg("error", exit ? `exit ${exit[1]}` : "failed")
				: theme.fg("dim", lineCount > 0 ? `${lineCount} lines` : "done");
			return glanceLine("Bash", args.command ?? "", summary, theme);
		}
		if (context.isError) {
			const exit = text.match(/Command exited with code (\d+)/);
			const output = text.replace(/\n*Command exited with code \d+\n?$/, "").trimEnd();
			const status = exit ? `exit ${exit[1]}` : "failed";
			if (expandedNow) {
				const lines = capLines(text.split("\n"), latestCap(mode, expanded), theme);
				return new Text(
					`  ${theme.fg("muted", "⎿")}  ${theme.fg("error", status)}\n` +
						lines.map((l) => GLANCE_INDENT + theme.fg("error", l)).join("\n"),
					0,
					0,
				);
			}
			const tail = lastLine(output);
			return resultLine(theme, tail ? `${status}: ${clip(tail, 80)}${truncationNote(result.details, theme)}` : status, true);
		}
		if (expandedNow) {
			return expandedBlock(text, theme, false, latestCap(mode, expanded));
		}
		const lineCount = text.split("\n").filter((l) => l.trim()).length;
		const head = firstLine(text);
		const count = lineCount > 1 ? theme.fg("muted", ` · ${lineCount} lines`) : "";
		return resultLine(theme, `${clip(head, 90) || "Done"}${count}${truncationNote(result.details, theme)}`);
	},
});

// ---------------------------------------------------------------------------
// read — `path:12-40` range suffix, "N lines" summary. Call and text half of
// the result are exported separately so image-history.ts (which owns `read`
// and appends inline image cells to the row) can compose them.
// ---------------------------------------------------------------------------

export function readCallSlot(args: any, theme: Theme, context?: any): Component {
	trackRow(context);
	const mode = groupMode(context?.toolCallId);
	const grouped = groupedCall(mode, context?.expanded, theme);
	if (grouped) return grouped;
	let arg = shortenPath(args.path ?? "");
	if (args.offset !== undefined || args.limit !== undefined) {
		const start = args.offset ?? 1;
		arg += theme.fg("muted", `:${start}${args.limit !== undefined ? `-${start + args.limit - 1}` : ""}`);
	}
	return callLine("Read", arg, theme, "", context);
}

export function readTextResult(result: any, { expanded, isPartial }: any, theme: Theme, cap?: number): Component {
	if (isPartial) return resultLine(theme, "Reading…");
	const text = resultText(result);
	if (!text) return new Text("", 0, 0);
	if (expanded) {
		return expandedBlock(text, theme, false, cap);
	}
	return resultLine(theme, `${text.split("\n").length} lines${truncationNote(result.details, theme)}`);
}

// ---------------------------------------------------------------------------
// edit — diff stat summary (+a −r), colored diff when expanded.
// ---------------------------------------------------------------------------

function diffStats(diff: string): { adds: number; dels: number } {
	let adds = 0;
	let dels = 0;
	for (const line of diff.split("\n")) {
		if (line.startsWith("+") && !line.startsWith("+++")) adds++;
		else if (line.startsWith("-") && !line.startsWith("---")) dels++;
	}
	return { adds, dels };
}

export const edit: RenderSlots = withToolNotes({
	renderShell: "self",
	renderCall(args, theme, context) {
		trackRow(context);
		const mode = groupMode(context?.toolCallId);
		const grouped = groupedCall(mode, context?.expanded, theme);
		if (grouped) return grouped;
		const count = Array.isArray(args.edits) ? args.edits.length : 0;
		const suffix = count > 1 ? theme.fg("muted", ` (${count} edits)`) : "";
		return callLine("Edit", shortenPath(args.path ?? ""), theme, suffix, context);
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		const expandedNow = expanded || mode.kind === "latest";
		if (isPartial && !glance(context)) return resultLine(theme, "Editing…");
		settleStatus(context, context.isError);
		if (glance(context)) {
			const diff: string | undefined = result.details?.diff;
			let summary = theme.fg("dim", "applied");
			if (context.isError) summary = theme.fg("error", clip(firstLine(resultText(result)) || "failed", 40));
			else if (diff) {
				const { adds, dels } = diffStats(diff);
				summary = `${theme.fg("success", `+${adds}`)} ${theme.fg("error", `−${dels}`)}`;
			}
			return glanceLine("Edit", shortenPath(args.path ?? ""), summary, theme);
		}
		const text = resultText(result);
		if (context.isError) {
			// Expanded views show the full error (Text word-wraps); collapsed
			// rows keep the single clipped line.
			if (expandedNow) return expandedBlock(text || "error", theme, true, latestCap(mode, expanded));
			return resultLine(theme, clip(firstLine(text) || "error", 90), true);
		}
		const diff: string | undefined = result.details?.diff;
		if (!diff) return resultLine(theme, "Applied");
		if (expandedNow) {
			const colored = withMore(diff, latestCap(mode, expanded) ?? MAX_EXPANDED_DIFF_LINES, theme)
				.split("\n")
				.map((line) => {
					if (line.startsWith("+") && !line.startsWith("+++")) return theme.fg("success", line);
					if (line.startsWith("-") && !line.startsWith("---")) return theme.fg("error", line);
					return theme.fg("muted", line);
				})
				.join("\n");
			const diffLines = colored.split("\n");
			return new Text(
				`  ${theme.fg("muted", "⎿")}  ${diffLines[0] ?? ""}\n` +
					diffLines.slice(1).map((l) => GLANCE_INDENT + l).join("\n"),
				0,
				0,
			);
		}
		const { adds, dels } = diffStats(diff);
		return new Text(
			`  ${theme.fg("muted", "⎿")}  ${theme.fg("success", `+${adds}`)} ${theme.fg("error", `−${dels}`)}`,
			0,
			0,
		);
	},
});

// ---------------------------------------------------------------------------
// write — line count from the call args (the result carries no size info).
// ---------------------------------------------------------------------------

export const write: RenderSlots = {
	renderShell: "self",
	renderCall(args, theme, context) {
		trackRow(context);
		const mode = groupMode(context?.toolCallId);
		const grouped = groupedCall(mode, context?.expanded, theme);
		if (grouped) return grouped;
		const lines = typeof args.content === "string" ? args.content.split("\n").length : 0;
		const suffix = lines > 0 ? theme.fg("muted", ` (${lines} lines)`) : "";
		return callLine("Write", shortenPath(args.path ?? ""), theme, suffix, context);
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		const expandedNow = expanded || mode.kind === "latest";
		if (isPartial && !glance(context)) return resultLine(theme, "Writing…");
		settleStatus(context, context.isError);
		if (glance(context)) {
			const summary = context.isError
				? theme.fg("error", clip(firstLine(resultText(result)) || "failed", 40))
				: theme.fg("dim", "written");
			return glanceLine("Write", shortenPath(args.path ?? ""), summary, theme);
		}
		if (context.isError) {
			const text = resultText(result);
			if (expandedNow) return expandedBlock(text || "error", theme, true, latestCap(mode, expanded));
			return resultLine(theme, clip(firstLine(text) || "error", 90), true);
		}
		return resultLine(theme, "Written");
	},
};

// ---------------------------------------------------------------------------
// grep / find / ls — count-based summaries. The call rows differ per tool,
// so countResult only provides the shared result slot.
// ---------------------------------------------------------------------------

function countResult(unitSingular: string, unitPlural: string, label: string, argOf: (args: any) => string) {
	return withToolNotes({
		renderShell: "self" as const,
		renderCall(args: any, theme: Theme, context: any): Component {
			trackRow(context);
			const mode = groupMode(context?.toolCallId);
			const grouped = groupedCall(mode, context?.expanded, theme);
			if (grouped) return grouped;
			return callLine(label, argOf(args), theme, "", context);
		},
		renderResult(result: any, { expanded, isPartial }: any, theme: Theme, context: any): Component {
			const args = context.args ?? {};
			const mode = groupMode(context?.toolCallId);
			const expandedNow = expanded || mode.kind === "latest";
			if (isPartial && !glance(context)) return resultLine(theme, "Searching…");
			settleStatus(context, context.isError);
			const text = resultText(result);
			const count = text.split("\n").filter((l: string) => l.trim()).length;
			const unit = count === 1 ? unitSingular : unitPlural;
			if (glance(context)) {
				const summary = context.isError
					? theme.fg("error", "failed")
					: theme.fg("dim", count > 0 ? `${count} ${unit}` : `no ${unitPlural}`);
				return glanceLine(label, argOf(args), summary, theme);
			}
			if (context.isError) {
				if (expandedNow) return expandedBlock(text || "error", theme, true, latestCap(mode, expanded));
				return resultLine(theme, clip(firstLine(text) || "error", 90), true);
			}
			if (expandedNow) {
				return expandedBlock(text, theme, false, latestCap(mode, expanded));
			}
			const limit = result.details?.matchLimitReached ??
				result.details?.resultLimitReached ?? result.details?.entryLimitReached;
			const note = limit ? theme.fg("warning", " (limit)") : "";
			return resultLine(theme, count > 0 ? `${count} ${unit}${note}` : `no ${unitPlural}${note}`);
		},
	});
}

export const grep: RenderSlots = {
	...countResult("match", "matches", "Grep", (args) => {
		let arg = `/${args.pattern ?? ""}/`;
		if (args.path) arg += ` in ${shortenPath(args.path)}`;
		if (args.glob) arg += ` (${args.glob})`;
		return arg;
	}),
};

export const find: RenderSlots = {
	...countResult("file", "files", "Find", (args) =>
		args.path ? `${args.pattern ?? ""} in ${shortenPath(args.path)}` : (args.pattern ?? "")),
};

export const ls: RenderSlots = {
	...countResult("entry", "entries", "Ls", (args) => shortenPath(args.path ?? ".")),
};

// ---------------------------------------------------------------------------
// generic — full claude-style treatment (grouping, glance lines, status dots,
// streaming output, expansion) for tools without bespoke renderers. Any
// extension that owns a tool can adopt the format in three lines:
//   const slots = genericSlots("My Tool", (args) => args.path ?? "");
//   pi.registerTool({ ...myTool, renderShell: slots.renderShell,
//     renderCall: slots.renderCall, renderResult: slots.renderResult });
// ---------------------------------------------------------------------------

export function genericSlots(label: string, argOf: (args: any) => string): RenderSlots {
	return withToolNotes({
		renderShell: "self",
		renderCall(args, theme, context) {
			trackRow(context);
			const mode = groupMode(context?.toolCallId);
			const grouped = groupedCall(mode, context?.expanded, theme);
			if (grouped) return grouped;
			return callLine(label, argOf(args ?? {}), theme, "", context);
		},
		renderResult(result, { expanded, isPartial }, theme, context) {
			const args = context.args ?? {};
			const mode = groupMode(context?.toolCallId);
			const expandedNow = expanded || mode.kind === "latest";
			// Exclude nix-comma's note blocks: they are delivered visually as
			// batch note lines (via the notify routing) and would render twice.
			const text = resultText(result, "[nix-comma]");
			if (isPartial && !context.isError) {
				if (glance(context)) {
					const live = lastLine(text);
					return resultLine(theme, live ? `Running… ${clip(live, 80)}` : "Running…");
				}
				return liveStream(text, theme);
			}
			settleStatus(context, context.isError);
			if (glance(context)) {
				const lineCount = text.split("\n").filter((l) => l.trim()).length;
				const summary = context.isError
					? theme.fg("error", "failed")
					: theme.fg("dim", lineCount > 0 ? `${lineCount} lines` : "done");
				return glanceLine(label, argOf(args), summary, theme);
			}
			if (context.isError) {
				const status = clip(firstLine(text) || "failed", 80);
				if (expandedNow) {
					const lines = capLines(text.split("\n"), latestCap(mode, expanded), theme);
					return new Text(
						`  ${theme.fg("muted", "⎿")}  ${theme.fg("error", status)}\n` +
							lines.map((l) => GLANCE_INDENT + theme.fg("error", l)).join("\n"),
						0,
						0,
					);
				}
				return resultLine(theme, status, true);
			}
			if (expandedNow) return expandedBlock(text, theme, false, latestCap(mode, expanded));
			return resultLine(theme, firstLine(text) || "Done");
		},
	});
}
