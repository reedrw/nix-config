// custom-ui: custom tool rendering for pi.
//
// Transcript as an interactive tree: every tool batch is a disclosure node
// (`▸/▾ Thought for Xs · Ran N tool calls`), its glance rows and thinking
// branches are children (`├─`/`╰─`, visible iff the header is open), and
// each child's output/reasoning is depth 3 (visible iff the child is open).
// Clicking toggles via OSC 8 pi-action:// links (fullscreen); ctrl+o walks
// the whole tree. Nothing is hidden by magic: thinking renders at its true
// chronological position whenever its ancestors are open.
//
// This is a *library* module, not an auto-discovered extension: pi only
// auto-loads `extensions/*.ts` and `extensions/*/index.ts`, so files under
// `lib/` are inert on their own. Tool-name ownership is split across
// extensions (nix-comma.ts owns `bash`'s spawn hook, custom-ui.ts owns
// everything else, including `read` with inline kitty-placeholder image
// rendering), and each imports its slots from here.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Container, getCapabilities, Text, visibleWidth } from "@earendil-works/pi-tui";
import type { Component } from "@earendil-works/pi-tui";
import { keyText, ToolExecutionComponent } from "@earendil-works/pi-coding-agent";
import type { Theme } from "@earendil-works/pi-coding-agent";

// Max width of a one-line call/summary before ellipsis. Terminal-width-aware
// wrapping is left to Text for expanded output; single-line slots are capped
// hard so parallel tool batches stay scannable.
const MAX_LINE = 120;
// Cap for expanded diff output; bash etc. rely on pi's upstream truncation.
const MAX_EXPANDED_DIFF_LINES = 400;
// Same cap for a fully expanded write: the file content rides in the call
// args (the result only carries a byte count) and can be arbitrarily large.
const MAX_EXPANDED_WRITE_LINES = 400;

// Global style toggle: `customUi: false` in .pi/settings.json (project)
// or ~/.pi/agent/settings.json (global; project wins) keeps pi's default
// rendering. Checked when extensions register their render slots, so a
// toggle needs a restart or /reload to take effect.
export function customUiEnabled(): boolean {
	for (const path of [
		join(process.cwd(), ".pi", "settings.json"),
		join(homedir(), ".pi", "agent", "settings.json"),
	]) {
		try {
			const settings = JSON.parse(readFileSync(path, "utf8")) as { customUi?: unknown };
			if (typeof settings.customUi === "boolean") return settings.customUi;
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

// `● label arg` — the call row. Status dot: an accent-colored dotsCircle
// spinner while the tool runs, then red on error / green on success. The
// call slot doesn't re-render by itself once the call settles, so the status
// is kept in context.state (shared across the row's slots) and written by
// settleStatus() from renderResult, which invalidates the row to repaint the
// dot. Claude Code style call: bold label with the argument inside
// parentheses.
function statusDot(theme: Theme, context: any): string {
	const status = context?.state?.status;
	if (status === "error") return theme.fg("error", "●");
	if (status === "success") return theme.fg("success", "●");
	return animState().inProgressDot();
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

// ── Tree glyphs ───────────────────────────────────────────────
//
// Classic ASCII-tree drawing (the tree(1) idiom): siblings use `├─`, the
// last child `╰─`. No full-height rail: `│` appears ONLY as the
// through-connector on the content lines of an expanded mid-list child
// (linking its corner past its content to the next sibling). The glyphs sit
// in base03/dim — the same muted register as the old `⎿` connector.
const TREE_BASE03 = "3e4b59";

// ` ├─ ` / ` ╰─ ` — the label prefix of a depth-2 child row: one column
// in, so the glyphs sit directly under the header's `▾` triangle (the
// header itself carries the leading pad).
function childLabelGlyph(last: boolean): string {
	return ` ${base16Fg("base03", TREE_BASE03)}${last ? "╰─" : "├─"}\x1b[39m `;
}

// Content prefix for an open child's tool output: the through-connector
// column plus the normal 5-cell result indent. The last child has no
// connector — the corner already turned.
function childOutputPrefix(mode: GroupMode, theme: Theme): string {
	if (mode.kind !== "child") return `  ${theme.fg("muted", "⎿")}  `;
	return (mode.last ? " " : ` ${base16Fg("base03", TREE_BASE03)}│\x1b[39m`) + GLANCE_INDENT;
}

// Content connector for an open child's LABEL row (call lines wrap too —
// the full argument is shown when the child is open): the bare 3-cell
// through-connector, aligned with the glyph column.
function childLabelContinuation(mode: GroupMode): string {
	if (mode.kind !== "child") return GLANCE_INDENT;
	return mode.last ? "    " : ` ${base16Fg("base03", TREE_BASE03)}│\x1b[39m  `;
}

// ── Tree-aware wrapping ──────────────────────────────────────
//
// PrefixedText wraps call lines and output blocks at the content width.
// pi-tui's wrapTextWithAnsi is plain greedy word-wrap: a long token (a
// store path inside Bash(...)) that misses the remaining space by one cell
// strands a stubby head — the status dot alone under the glyph. The tree
// wrapper splits tokens AFTER `- _ / . ,` and spaces (so paths, flags and
// dotted versions break at natural points), hard-breaks runs that contain
// no split character at all, and re-opens the active OSC 8 link + SGR
// state on every continuation line so clicks and colors survive the break.

const TREE_WRAP_SPLIT = new Set([" ", "-", "_", "/", ".", ","]);
const TREE_ANSI_SPLIT_RE = /(\x1b\[[0-?]*[ -/]*[@-~]|\x1b\]8;;[^\x1b]*\x1b\\)/;
const TREE_OSC8_CLOSE = "\x1b]8;;\x1b\\";

interface TreeWrapUnit {
	codes: string; // zero-width ANSI codes queued before this unit
	text: string;
	hard?: true; // a forced break (hard newline in the source)
}

function tokenizeTree(text: string): TreeWrapUnit[] {
	const units: TreeWrapUnit[] = [];
	const segmenter = new Intl.Segmenter("en", { granularity: "grapheme" });
	let carry = ""; // codes queued before the current run
	let run = ""; // the current run of non-split graphemes
	const flush = (): void => {
		if (run === "") return;
		units.push({ codes: carry, text: run });
		carry = "";
		run = "";
	};
	for (const part of text.split(TREE_ANSI_SPLIT_RE)) {
		if (!part) continue;
		if (part.startsWith("\x1b")) {
			flush();
			carry += part;
			continue;
		}
		for (const g of segmenter.segment(part)) {
			if (g.segment === "\n") {
				flush();
				units.push({ codes: carry, text: "", hard: true });
				carry = "";
				continue;
			}
			run += g.segment;
			if (TREE_WRAP_SPLIT.has(g.segment)) flush();
		}
	}
	flush();
	return units;
}

export function wrapTreeText(text: string, width: number): string[] {
	const w = Math.max(1, width);
	const segmenter = new Intl.Segmenter("en", { granularity: "grapheme" });
	const lines: string[] = [];
	let line = "";
	let lineW = 0;
	let sgr = ""; // active SGR after placed units ("" = plain)
	let osc8 = ""; // active OSC 8 opener after placed units ("" = none)

	const applyCode = (code: string): void => {
		if (code.startsWith("\x1b]8;;")) {
			const url = code.slice(4, code.indexOf("\x1b", 4));
			osc8 = url === "" ? "" : code;
		} else if (code.endsWith("m")) {
			const params = code.slice(2, -1);
			sgr = params === "" || /^0(;0)*$/.test(params) ? "" : sgr + code;
		}
	};
	const place = (u: TreeWrapUnit): void => {
		line += u.codes + u.text;
		lineW += visibleWidth(u.text);
		for (const part of u.codes.split(TREE_ANSI_SPLIT_RE)) {
			if (part) applyCode(part);
		}
	};
	const closeLine = (): void => {
		let out = line;
		if (osc8) out += TREE_OSC8_CLOSE;
		if (sgr) out += "\x1b[0m";
		lines.push(out);
		line = (osc8 ?? "") + (sgr ?? "");
		lineW = 0;
	};

	const work = tokenizeTree(text);
	for (let ui = 0; ui < work.length; ui++) {
		const u = work[ui];
		if (u.hard) {
			// forced break: close what is on the line, carry queued codes over
			if (lineW > 0) closeLine();
			line += u.codes;
			continue;
		}
		const uw = visibleWidth(u.text);
		if (lineW + uw <= w) {
			place(u);
			continue;
		}
		if (uw > w) {
			// a run with no split character, longer than the line:
			// hard-break it grapheme-wise, filling the remaining space first.
			const segs = [...segmenter.segment(u.text)].map((s) => s.segment);
			const avail = Math.max(0, w - lineW);
			let idx = 0;
			let fill = "";
			let fillW = 0;
			while (idx < segs.length && fillW + visibleWidth(segs[idx]) <= avail) {
				fill += segs[idx];
				fillW += visibleWidth(segs[idx]);
				idx++;
			}
			if (fill !== "") {
				place({ codes: u.codes, text: fill });
			}
			closeLine();
			// the remainder re-tokenizes (its split chars and codes survive);
			// a fresh line always fits the first grapheme, so this recurses
			// at most one level.
			const rest = segs.slice(fill === "" ? 0 : idx).join("");
			const payload = fill === "" ? u.codes + rest : rest;
			work.splice(ui + 1, 0, ...tokenizeTree(payload));
			continue;
		}
		closeLine();
		place(u);
	}
	if (lineW > 0 || lines.length === 0) {
		let out = line;
		if (osc8) out += TREE_OSC8_CLOSE;
		if (sgr) out += "\x1b[0m";
		lines.push(out);
	}
	return lines;
}

// A text block whose content wraps at (width − prefix) with EVERY segment
// after the first carrying the tree continuation prefix — terminal-width
// wrapping must never break the left rail (§5): a long output line or full
// call argument that soft-wraps would otherwise continue at column 0,
// orphaned from its branch. The prefix (the `├─`/`╰─` glyph on call rows,
// the connector column on output blocks) lands on the FIRST segment only;
// hard newlines in the content (multi-line bash commands!) and soft wraps
// alike continue with contPrefix — one node, one glyph.
// Wrapping happens here (ANSI/OSC-aware, same helper pi-tui's Text uses)
// instead of inside Text, which wraps at the full width.
class PrefixedText implements Component {
	private text: string;
	private prefix: string;
	private contPrefix: string;
	private cache?: { width: number; lines: string[] };
	constructor(text: string, prefix: string, contPrefix = prefix) {
		this.text = text;
		this.prefix = prefix;
		this.contPrefix = contPrefix;
	}
	invalidate(): void {
		this.cache = undefined;
	}
	render(width: number): string[] {
		const w = Math.max(20, width);
		if (this.cache?.width === w) return this.cache.lines;
		const inner = Math.max(10, w - visibleWidth(this.prefix));
		const segs = wrapTreeText(this.text, inner);
		const lines = segs.map((seg, i) => (i === 0 ? this.prefix : this.contPrefix) + seg);
		this.cache = { width: w, lines };
		return lines;
	}
}

function callLine(label: string, arg: string, theme: Theme, suffix = "", mode?: GroupMode, context?: any): Component {
	// Open children show the full argument — clip() would re-truncate the very
	// thing expansion is for. The collapsed view is the glance row, which
	// clips. The full argument can exceed the terminal width: wrap it here at
	// (width − glyph) with the connector on every continuation, so the rail
	// never breaks (PrefixedText).
	const body = arg
		? `${theme.fg("toolTitle", "(")}${theme.fg("accent", arg)}${theme.fg("toolTitle", ")")}`
		: "";
	// The call row is a click target: clicking collapses the child again.
	const url = context?.toolCallId ? `pi-action://node/tool/${encodeURIComponent(context.toolCallId)}` : undefined;
	const core = `${statusDot(theme, context)} ${theme.fg("toolTitle", theme.bold(label))}${body}${suffix}`;
	const wrapped = url ? linkWrap(core, url) : core;
	if (mode?.kind === "child") {
		// PrefixedText supplies the glyph on the first segment — the core must
		// not carry it too (it would double).
		return new PrefixedText(wrapped, childLabelGlyph(mode.last), childLabelContinuation(mode));
	}
	return new Text(wrapped, 0, 0);
}

// `⎿  summary` — the result row, indented under the call. Muted connector,
// muted summary on success (dim is too dark against most themes), red on error.
function resultLine(theme: Theme, summary: string, error = false, mode?: GroupMode): Component {
	const body = error ? theme.fg("error", summary) : theme.fg("muted", summary);
	const m = mode ?? { kind: "normal" as const };
	if (m.kind === "child") return new PrefixedText(body, childOutputPrefix(m, theme));
	return new PrefixedText(body, childOutputPrefix(m, theme), GLANCE_INDENT);
}

// Expanded output block: the first line rides the ⎿ connector and the rest
// are indented to the same column, so the whole block lines up.
const GLANCE_INDENT = "     "; // width of `  ⎿  `
// Lines of output shown while a bash command streams.
const LIVE_OUTPUT_LINES = 20;

// Live output while a command streams: tail-capped, aligned like the expanded
// view, with a muted marker when older lines are trimmed.
function liveStream(text: string, theme: Theme, mode?: GroupMode, url?: string): Component {
	const lines = text.split("\n").filter((l) => l.trim());
	const tail = lines.slice(-LIVE_OUTPUT_LINES);
	const parts: string[] = [];
	if (lines.length > LIVE_OUTPUT_LINES) parts.push(theme.fg("muted", "…"));
	parts.push(...tail.map((l) => theme.fg("toolOutput", l)));
	const prefix = childOutputPrefix(mode ?? { kind: "normal" }, theme);
	const block = new PrefixedText(parts.join("\n"), prefix, mode?.kind === "child" ? prefix : GLANCE_INDENT);
	return url ? new ClickToggle(block, url) : block;
}
// Head-only preview for the auto-expanded newest child of a running batch:
// long outputs are pinned to a fixed height so the screen doesn't jump while
// the agent works. Deliberate expansion lifts the cap entirely.
const LATEST_EXPANDED_LINES = 16;

// Toggle URL for a tool row's own node (glance/call row and, since the body
// is clickable too, its expanded output).
function toolToggleUrl(context: any): string | undefined {
	return context?.toolCallId ? `pi-action://node/tool/${encodeURIComponent(context.toolCallId)}` : undefined;
}

// Click-to-collapse on expanded content: an expanded node's BODY (thinking
// text, tool output) carries the same toggle URL as its label, so clicking
// anywhere in the content shrinks the node back down. Per-line wrapping
// keeps OSC 8 state well-defined regardless of the inner component's
// structure; blank lines stay unwrapped.
class ClickToggle implements Component {
	private inner: Component;
	private url: string;
	constructor(inner: Component, url: string) {
		this.inner = inner;
		this.url = url;
	}
	invalidate(): void {
		this.inner.invalidate();
	}
	render(width: number): string[] {
		return this.inner.render(width).map((line) => (line.trim() ? linkWrap(line, this.url) : line));
	}
}

// Live-cap for a row's output: only the auto-opened newest child of a
// running batch is capped (today's "latest row" behavior, re-expressed).
export function outputCap(mode: GroupMode): number | undefined {
	return mode.kind === "child" ? mode.cap : undefined;
}

function capLines(lines: string[], cap: number | undefined, theme: Theme): string[] {
	if (cap === undefined || lines.length <= cap) return lines;
	const rest = lines.length - cap;
	return [...lines.slice(0, cap), theme.fg("muted", `… +${rest} more lines (${keyText("app.tools.expand")} to expand)`)];
}

function expandedBlock(text: string, theme: Theme, error = false, cap?: number, mode?: GroupMode, url?: string): Component {
	const color = error ? "error" : "toolOutput";
	const lines = capLines(text.split("\n"), cap, theme);
	const body = lines.map((l) => theme.fg(color, l)).join("\n");
	const prefix = childOutputPrefix(mode ?? { kind: "normal" }, theme);
	const block = new PrefixedText(body, prefix, mode?.kind === "child" ? prefix : GLANCE_INDENT);
	return url ? new ClickToggle(block, url) : block;
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
// ── Transcript tree state ─────────────────────────────
//
// Every rendered element is a node in a tree with an `open` flag:
//
//   depth 1   batch header            (the tree node; collapsed by default)
//   depth 2   glance rows, thought branches   (visible iff header open)
//   depth 3   tool output, expanded thinking   (visible iff that child open)
//
// A batch's children merge tool calls and thinking messages into one
// chronological list (`children`); renderers walk it to place `├─`/`╰─`
// (last child gets the corner). Batch open/closed is USER state with live
// defaults — no derived `collapsed`/`folded`/`latest` flags:
//
// - a RUNNING batch (the current one) auto-opens, and its newest child
//   auto-opens with the 16-line live cap;
// - a user collapse of a running batch is STICKY (wins over auto-open until
//   the user re-opens or a new batch starts);
// - settled batches default closed; user-opened children persist.
//
// Leading thoughts (§2.3): a contiguous run of pure-thinking messages
// directly before a batch's first tool call joins the batch — the FIRST
// becomes the anchor and hosts the header in the thinking-fold renderer; the
// rest are ordinary thought branches. Visible text or a user message in
// between breaks the run and keeps them standalone.
//
// State lives on globalThis: this lib module is imported by several
// independent extensions which may each get their own module instance.
// custom-ui.ts registers the event handlers; the renderers in every
// extension read the shared state.

type TreeChild = { kind: "tool"; id: string } | { kind: "thought"; ts: number };

interface TreeBatch {
	ids: string[];
	// message timestamps of the batch's thought branches, in order; the first
	// leading thought (when any) is the anchor hosting the header.
	thoughts: number[];
	// ids and thoughts merged into one ordered child list (scan/stream order).
	children: TreeChild[];
	// Leading thought hosting the header (fold-side); undefined for bare
	// batches (the first tool row carries the header, as before).
	anchor?: number;
	// User toggle; undefined = live default (running → open, settled → closed).
	open?: boolean;
	// User collapsed while running: wins over the auto-open until re-opened.
	stickyClosed?: boolean;
	// Batch-wide edit-output override driven by the header diffstat click:
	// true = every Edit call's output open, false = all closed, undefined =
	// per-row defaults (auto-open newest / openTools). Dissolved by per-row
	// toggles and ctrl+o walks.
	editsOpen?: boolean;
	// Set while the diffstat click is what opened the header, so the second
	// diff click can collapse the whole tree back (a header the user opened
	// themselves is left alone on diff-close).
	editsOpenedHeader?: boolean;
	// Live batch (more tool calls may join). Settled batches keep their state
	// but default closed.
	running: boolean;
	// Index into DOTS_SPINNERS, drawn once per batch so the header spinner
	// varies across turns (zentui-style).
	spinner: number;
}

interface GroupState {
	counter: number;
	order: Map<string, number>;
	memberBatch: Map<string, number>;
	thoughtBatch: Map<number, number>;
	batches: TreeBatch[];
	current: number | undefined;
	// Pure-thinking messages since the last visible separator (text, user
	// message, batch close). When a tool call opens the next batch, this run
	// joins it — first entry becomes the anchor. Nothing else survives into
	// the run: visible text dissolves it (hosting would reorder the think
	// past the narration).
	leadingRun: number[];
	// Depth-3 flags: tool output and thinking reasoning. openTools holds
	// user-opened children; closedTools remembers an explicit user close of
	// the auto-opened newest child (beats the auto-open while it lasts).
	openTools: Set<string>;
	closedTools: Set<string>;
	openThoughts: Set<number>;
	// Per-row invalidate callbacks, registered by renderers, so state changes
	// can force the affected rows to re-render — rows render cached children
	// otherwise. Tool rows register via trackRow; thought rows register from
	// the thinking-fold renderer (registerThoughtRow).
	invalidators: Map<string, () => void>;
	thoughtRows: Map<number, () => void>;
	notes: Map<string, string[]>;
	// toolCallIds that render through the edit slots (registered on first
	// render) — the header diffstat override and totals only reach edit rows.
	editIds: Set<string>;
	// Settled diffstat per edit toolCallId (+added/−removed lines), summed
	// into the batch header's diff section.
	editStats: Map<string, { adds: number; dels: number }>;
}

const GROUP_STATE_KEY = "__piCustomUiToolGroups";

function freshGroupState(): GroupState {
	return {
		counter: 0,
		order: new Map(),
		memberBatch: new Map(),
		thoughtBatch: new Map(),
		batches: [],
		current: undefined,
		leadingRun: [],
		openTools: new Set(),
		closedTools: new Set(),
		openThoughts: new Set(),
		invalidators: new Map(),
		thoughtRows: new Map(),
		notes: new Map(),
		editIds: new Set(),
		editStats: new Map(),
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

// Thought rows live in the fold's components; the fold registers an
// invalidator per timestamp on first render (registerThoughtRow), so tree
// state changes can re-render them too — the old "fold rows have no
// invalidator" gap, closed.
function invalidateThoughtRows(timestamps: Iterable<number>): void {
	const s = groupState();
	for (const ts of timestamps) {
		const invalidate = s.thoughtRows.get(ts);
		if (invalidate) setTimeout(invalidate, 0);
	}
}

function invalidateChild(child: TreeChild | undefined): void {
	if (!child) return;
	if (child.kind === "tool") invalidateRows([child.id]);
	else invalidateThoughtRows([child.ts]);
}

function groupState(): GroupState {
	const w = globalThis as Record<string, unknown>;
	if (!w[GROUP_STATE_KEY]) w[GROUP_STATE_KEY] = freshGroupState();
	return w[GROUP_STATE_KEY] as GroupState;
}

// A tool call joins the current running batch, or opens a new one. A new
// batch consumes the pending leading-thought run: the first think becomes
// the anchor (it hosts the header in the fold), the rest are branches —
// think → tools → think → tools maps to children in exactly that order.
// Idempotent: custom-ui tracks on tool_execution_start (fires for every
// call, BEFORE pi validates args) and keeps the legacy tool_call handler;
// a call that passes validation fires both.
export function trackGroupToolCall(toolCallId: string): void {
	const s = groupState();
	if (s.memberBatch.has(toolCallId)) return;
	s.order.set(toolCallId, ++s.counter);
	if (s.current === undefined) {
		const anchorRun = s.leadingRun;
		s.leadingRun = [];
		s.batches.push({
			ids: [],
			thoughts: [...anchorRun],
			children: anchorRun.map((ts) => ({ kind: "thought" as const, ts })),
			anchor: anchorRun[0],
			running: true,
			spinner: Math.floor(Math.random() * DOTS_SPINNERS.length),
		});
		s.current = s.batches.length - 1;
		for (const ts of anchorRun) s.thoughtBatch.set(ts, s.current);
		// The leading think(s) re-render: the standalone row tucks under its
		// own block header (anchor hosting, §2.3).
		invalidateThoughtRows(anchorRun);
	}
	const batch = s.batches[s.current];
	// Rows affected by this join: the previously-last child re-renders from
	// `╰─` to `├─`, the previously-newest TOOL drops its auto-opened output to
	// a glance row, and the header carrier updates its live count. (Only
	// these — invalidating every earlier child would be O(n²) on long
	// batches.)
	const prevChildren = batch.children;
	const prevLast = prevChildren[prevChildren.length - 1];
	let prevLastTool: string | undefined;
	for (let i = prevChildren.length - 1; i >= 0; i--) {
		const child = prevChildren[i];
		if (child.kind === "tool") {
			prevLastTool = child.id;
			break;
		}
	}
	batch.ids.push(toolCallId);
	batch.children.push({ kind: "tool", id: toolCallId });
	s.memberBatch.set(toolCallId, s.current);
	setBatchOpen(true);
	if (prevLast) invalidateChild(prevLast);
	if (prevLastTool && prevLastTool !== (prevLast?.kind === "tool" ? prevLast.id : undefined)) {
		invalidateRows([prevLastTool]);
	}
	invalidateRows([batch.ids[0]]);
	// The row itself: pi renders the call row while args are still streaming,
	// BEFORE the tool_call event fires — that first render is untracked
	// (normal mode). Without this invalidation a tool whose args complete in
	// one pass would keep its full-width untracked rendering forever.
	invalidateRows([toolCallId]);
}

// A thinking message started streaming (thinking_delta). Under an open batch
// it joins as a thought branch at its true chronological position; otherwise
// it is a standalone top-level row pending anchor assignment.
export function trackThoughtStart(ts: number): void {
	const s = groupState();
	if (s.current !== undefined) {
		const batch = s.batches[s.current];
		if (batch.thoughts.includes(ts)) return;
		batch.thoughts.push(ts);
		batch.children.push({ kind: "thought", ts });
		s.thoughtBatch.set(ts, s.current);
		// The previously-last child re-renders from `╰─` to `├─`.
		invalidateChild(batch.children[batch.children.length - 2]);
	} else {
		if (!s.leadingRun.includes(ts)) s.leadingRun.push(ts);
	}
}

// Close the running batch: visible assistant text, a user message, or
// agent_end settles it (its header goes static, children default hidden) and
// dissolves the pending leading-thought run — a think followed by narration
// stays standalone, never anchoring the NEXT batch.
export function closeBatch(): void {
	const s = groupState();
	if (s.current !== undefined) {
		const batch = s.batches[s.current];
		batch.running = false;
		invalidateRows(batch.ids);
		invalidateThoughtRows(batch.thoughts);
		s.current = undefined;
	}
	s.leadingRun = [];
	setBatchOpen(false);
}

// Effective open state of a batch header: user toggle first, then the live
// defaults (running → open unless sticky-closed, settled → closed).
function batchOpen(batch: TreeBatch): boolean {
	return batch.open ?? (batch.running ? !batch.stickyClosed : false);
}
export function pushToolNote(text: string): boolean {
	const s = groupState();
	if (s.current === undefined) return false;
	const batch = s.batches[s.current];
	const latest = batch.ids[batch.ids.length - 1];
	if (!latest) return false;
	const list = s.notes.get(latest) ?? [];
	list.push(text);
	s.notes.set(latest, list);
	invalidateRows([latest]);
	return true;
}

// Append a row's accumulated notes (dim, tree-indented) under its result.
// Notes attach to a child; if its parent header is closed the child renders
// nothing at all, so the notes vanish with it.
export function attachNotes(component: Component, context: any, theme: Theme): Component {
	const id = context?.toolCallId;
	const notes = id ? groupState().notes.get(id) : undefined;
	if (!notes || notes.length === 0) return component;
	const mode = groupMode(id);
	const prefix = childOutputPrefix(mode, theme);
	const stack = new Container();
	stack.addChild(component);
	for (const note of notes) {
		stack.addChild(new Text(`${prefix}${theme.italic(theme.fg("dim", clip(note, 90)))}`, 0, 0));
	}
	return stack;
}

// Wrap a slot set so notes pushed while its result renders appear under it —
// but only while the row is visible (a closed parent header hides the child,
// and notes with it).
export function withToolNotes<T extends RenderSlots>(slots: T): T {
	const { renderResult, ...rest } = slots;
	if (!renderResult) return slots;
	return {
		...rest,
		renderResult(result: any, options: any, theme: Theme, context: any): Component {
			const component = renderResult.call(this, result, options, theme, context);
			const mode = groupMode(context?.toolCallId);
			if (mode.kind === "child" && !mode.headerOpen) return component;
			return attachNotes(component, context, theme);
		},
	} as T;
}

export function resetToolGroups(): void {
	(globalThis as Record<string, unknown>)[GROUP_STATE_KEY] = freshGroupState();
	setBatchOpen(false);
}

// Rebuild the tree from session history — the scan mirror of the live rules:
// visible assistant text or a user message closes the batch (and dissolves
// the pending leading-thought run); a thinking message joins the open batch
// as a branch, or pends as a standalone leading think when no batch is open;
// tool calls join the open batch or open the next one (consuming the
// leading run). Narrated messages (thinking → text → toolCall) process in
// stream order, so their thinking joins the PRECEDING batch their reasoning
// streamed under.
export function scanToolGroupsFromHistory(entries: Iterable<{ type: string; message?: unknown }>): void {
	// Session-switch flows (launch resume, /resume, /new, /fork) render the
	// restored transcript BEFORE this rescan runs — those rows rendered
	// untracked (normal mode: full-width call lines, no tree grammar), and
	// their row invalidators are registered against the state this scan is
	// about to replace. Snapshot them and re-fire after the scan so every
	// restored row repaints through its own renderCall with the rebuilt
	// grouping. Only ids the scan actually tracks are re-fired: a stale id
	// would invalidate a component from a discarded session.
	const stale = new Map(groupState().invalidators);
	resetToolGroups();
	const s = groupState();
	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const message = entry.message as { role?: unknown; content?: unknown } | undefined;
		if (!message) continue;
		if (message.role === "user") {
			closeBatch();
			continue;
		}
		if (message.role !== "assistant") continue;
		const hasVisible = Array.isArray(message.content) &&
			message.content.some(
				(part) =>
					part !== null && typeof part === "object" &&
					(part as { type?: unknown }).type === "text" &&
					typeof (part as { text?: unknown }).text === "string" &&
					((part as { text: string }).text).trim().length > 0,
			);
		const hasThinking = Array.isArray(message.content) &&
			message.content.some(
				(part) =>
					part !== null && typeof part === "object" &&
					(part as { type?: unknown }).type === "thinking",
			);
		const ts = typeof (message as { timestamp?: unknown }).timestamp === "number"
			? (message as { timestamp: number }).timestamp
			: undefined;
		if (hasThinking && ts !== undefined) {
			if (s.current !== undefined) {
				trackThoughtStart(ts);
			} else if (!hasVisible) {
				// Pure thinking with no open batch: standalone for now; joins
				// the next batch's leading run unless text intervenes.
				if (!s.leadingRun.includes(ts)) s.leadingRun.push(ts);
			}
		}
		if (hasVisible) closeBatch();
		if (Array.isArray(message.content)) {
			for (const part of message.content) {
				if (
					part !== null && typeof part === "object" &&
					(part as { type?: unknown }).type === "toolCall" &&
					typeof (part as { id?: unknown }).id === "string"
				) {
					trackGroupToolCall((part as { id: string }).id);
				}
			}
		}
	}
	// Repaint the pre-scan rows (see the snapshot above), deferred like every
	// row invalidation: invalidate() from inside a render pass re-enters the
	// row's updateDisplay() mid-rebuild.
	for (const [id, invalidate] of stale) {
		if (s.memberBatch.has(id)) setTimeout(invalidate, 0);
	}
}

export type GroupMode =
	| { kind: "normal" }
	| {
			kind: "child";
			batchIndex: number;
			// First child: carries the header for bare batches (no anchor).
			first: boolean;
			// The header is hosted by the anchor think (fold-side) — the first
			// tool row must not render it too.
			anchorHosted: boolean;
			headerOpen: boolean;
			running: boolean;
			// Tool-call count (header text).
			count: number;
			// Last child of the batch: gets the `╰─` corner, no connector.
			last: boolean;
			// Depth-3 flag: this child's output is open (auto newest / user
			// toggle). pi's ctrl+o flag is OR-ed in by the renderers.
			outputOpen: boolean;
			// 16-line live cap when auto-opened (newest child of a running
			// batch); deliberate expansion lifts it.
			cap: number | undefined;
			spinner: number;
	  };

export function groupMode(toolCallId: string | undefined | null): GroupMode {
	if (!toolCallId) return { kind: "normal" };
	const s = groupState();
	const idx = s.memberBatch.get(toolCallId);
	if (idx === undefined) return { kind: "normal" };
	const batch = s.batches[idx];
	if (!batch) return { kind: "normal" };
	const lastChild = batch.children[batch.children.length - 1];
	const last = lastChild?.kind === "tool" && lastChild.id === toolCallId;
	const newest = batch.ids[batch.ids.length - 1] === toolCallId;
	const headerOpen = batchOpen(batch);
	const userOpen = s.openTools.has(toolCallId);
	// Auto-open applies only while the header is open — a closed header hides
	// its children entirely (sticky user collapse wins over auto-open). Solo
	// trees carrying a reasoning block are excluded: 1 tool + thoughts keeps
	// its output glanced; only a bare 1-tool tree auto-expands its output.
	const soloWithThoughts = batch.ids.length === 1 && batch.thoughts.length > 0;
	const autoOpen = batch.running && headerOpen && newest && !soloWithThoughts && !s.closedTools.has(toolCallId);
	let outputOpen = userOpen || autoOpen;
	let cap = autoOpen && !userOpen ? LATEST_EXPANDED_LINES : undefined;
	// The header diffstat's batch-wide edit override (set by clicking the
	// +N −M section) beats per-row defaults for Edit rows; a deliberate
	// override is uncapped.
	if (s.editIds.has(toolCallId) && batch.editsOpen !== undefined) {
		outputOpen = batch.editsOpen;
		cap = undefined;
	}
	return {
		kind: "child",
		batchIndex: idx,
		first: batch.ids[0] === toolCallId,
		anchorHosted: batch.anchor !== undefined,
		headerOpen,
		running: batch.running,
		count: batch.ids.length,
		last,
		outputOpen,
		cap,
		spinner: batch.spinner,
	};
}

// Thinking timings, published by the thinking-fold renderer
// (lib/thinking-fold/renderer.ts — part of this extension suite) and read
// here for the batch headers and the turn summary. Raw entries (start +
// optional completion); durations derive from them. Lives on globalThis: the
// lib is imported by several independent extensions which may each get their
// own module instance, and /reload keeps globalThis across reloads.
const THOUGHT_TIMINGS_KEY = "__piCustomUiThoughtTimings";

export interface ThoughtTiming {
	startedAt: number;
	completedAt?: number;
}

export function noteThinkingTiming(timestamp: number, timing: ThoughtTiming): void {
	const w = globalThis as Record<string, unknown>;
	const map = (w[THOUGHT_TIMINGS_KEY] ??= new Map()) as Map<number, ThoughtTiming>;
	map.set(timestamp, { startedAt: timing.startedAt, completedAt: timing.completedAt });
}

export function thoughtTiming(timestamp: number): ThoughtTiming | undefined {
	const w = globalThis as Record<string, unknown>;
	const map = w[THOUGHT_TIMINGS_KEY] as Map<number, ThoughtTiming> | undefined;
	return map?.get(timestamp);
}

// Batch duration: every thought branch's thinking (in-progress entries
// included — thoughts are stamped into the batch at thinking_delta, so a
// branch streaming right now counts up in real time). Sub-half-second
// totals are noise, not a phase worth naming.
function thoughtForMs(keys: number[] | undefined): number | undefined {
	let total = 0;
	for (const key of keys ?? []) {
		const timing = thoughtTiming(key);
		if (timing) total += Math.max(0, (timing.completedAt ?? Date.now()) - timing.startedAt);
	}
	return total >= 500 ? total : undefined;
}

// True while the animated batch header is on screen: every running batch
// renders a live header (`⠋ Sautéing… 4s · ↑12.4k · 2 tool calls`) — its
// spinner owns the one-spinner rule, so the dead-air loader must stay dark
// even when no tool is in flight and thinking deltas have paused (provider
// latency). User-collapsed running batches keep the animated header too.
export function batchHeaderAnimated(): boolean {
	return groupState().current !== undefined;
}

// Called on a timer while a batch runs: bumps the animation clock and
// re-renders the batch — the animated header AND the in-progress dotsCircle
// dots on running tool rows (solo batches included, so a single running tool
// still animates). The anchor think re-renders too: it hosts the animated
// header line (fold-side, via its registered invalidator). Returns false
// when no batch is running, letting the caller stop its timer until the
// next tool_call/thinking_delta restarts it.
export function tickOpenBatch(): boolean {
	const s = groupState();
	if (s.current === undefined) return false;
	animState().tick();
	const batch = s.batches[s.current];
	invalidateRows(batch.ids);
	if (batch.anchor !== undefined) invalidateThoughtRows([batch.anchor]);
	animState().requestRender?.();
	return true;
}

function formatThought(ms: number): string {
	const s = ms / 1000;
	if (s < 60) return `${s.toFixed(1)}s`;
	return `${Math.floor(s / 60)}m ${Math.round(s % 60)}s`;
}

export function groupHeaderLine(
	theme: Theme,
	count: number,
	thoughtMs?: number,
	open = false,
	url?: string,
	diff?: { adds: number; dels: number },
	diffUrl?: string,
): string {
	// Bold grey (base03 — same tone as the standalone thinking labels),
	// italic label. Standard disclosure triangles: ▸ collapsed, ▾ expanded —
	// differing by exactly one glyph, so mixed states scan cleanly. The
	// leading space indents the header one cell, aligning it under the
	// standalone thinking rows above it. The whole header row is one click
	// target; the triangle itself signals expandability, so no hint suffix
	// (ctrl+o stays in pi's footer docs).
	const glyph = open ? "▾" : "▸";
	const thought = thoughtMs === undefined ? "" : `Thought for ${formatThought(thoughtMs)} · `;
	const label = `Ran ${count} tool call${count === 1 ? " " : "s"}`;
	const grey = base16Fg("base03", "6a737d");
	const head = ` \x1b[1m${grey}${glyph} ${theme.italic(`${thought}${label}`)}\x1b[22m\x1b[39m`;
	// The diffstat is its own click target (toggles the batch's Edit calls'
	// output) — a SEPARATE OSC 8 span appended after the header link, never
	// nested inside it (an inner OSC 8 opener would silently close the outer
	// span mid-line). Rendered only once an Edit has settled with changes.
	let stat = "";
	if (diff && diffUrl && (diff.adds > 0 || diff.dels > 0)) {
		// Local const: tsc loses the diffUrl narrowing inside the nested
		// template literal, and linkWrap's url param demands a string.
		const body = `${theme.fg("success", `+${diff.adds}`)} ${theme.fg("error", `−${diff.dels}`)}`;
		stat = `  ${linkWrap(body, diffUrl)}`;
	}
	return `${url ? linkWrap(head, url) : head}${stat}`;
}

// ── Live batch header: spinner + shimmer verb ─────────────────
//
// While a batch is running (open, header visible) the static settled header is
// replaced by an animated one, adapted from two sources:
//
// - spinner: the cli-spinners `dots` family (sindresorhus/cli-spinners,
//   MIT), one variant drawn at random per batch so turns vary. Frames only;
//   cadence is the tick timer in custom-ui.ts (80ms, the family's default
//   interval).
// - text: the shimmer effect from arpagon/pi-animations (MIT), ported but
//   recolored — the original sweeps a hardcoded magenta→cyan rainbow over a
//   grey base, ours sweeps a gradient built from the stylix palette
//   (base0D→base0E→base0C over a base04 base tone) so it follows the
//   terminal theme. Falls back to the original rainbow when base16.json is
//   unavailable.
//
// The verb catalog is lmilojevicc/pi-zentui's working-line message list
// (MIT), selected deterministically per batch so restored sessions and
// re-renders agree.

export const DOTS_SPINNERS: readonly (readonly string[])[] = [
	["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
	["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
	["⠋", "⠙", "⠚", "⠞", "⠖", "⠦", "⠴", "⠲", "⠳", "⠓"],
	["⠄", "⠆", "⠇", "⠋", "⠙", "⠸", "⠰", "⠠", "⠰", "⠸", "⠙", "⠋", "⠇", "⠆"],
	["⠋", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠦", "⠖", "⠒", "⠐", "⠐", "⠒", "⠓", "⠋"],
	["⠁", "⠉", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠤", "⠄", "⠄", "⠤", "⠴", "⠲", "⠒", "⠂", "⠂", "⠒", "⠚", "⠙", "⠉", "⠁"],
	["⠈", "⠉", "⠋", "⠓", "⠒", "⠐", "⠐", "⠒", "⠖", "⠦", "⠤", "⠠", "⠠", "⠤", "⠦", "⠖", "⠒", "⠐", "⠐", "⠒", "⠓", "⠋", "⠉", "⠈"],
	["⠁", "⠁", "⠉", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠤", "⠄", "⠄", "⠤", "⠠", "⠠", "⠤", "⠦", "⠖", "⠒", "⠐", "⠐", "⠒", "⠓", "⠋", "⠉", "⠈", "⠈"],
	["⢹", "⢺", "⢼", "⣸", "⣇", "⡧", "⡗", "⡏"],
	["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"],
	["⠁", "⠂", "⠄", "⡀", "⢀", "⠠", "⠐", "⠈"],
	["⢀⠀", "⡀⠀", "⠄⠀", "⢂⠀", "⡂⠀", "⠅⠀", "⢃⠀", "⡃⠀", "⠍⠀", "⢋⠀", "⡋⠀", "⠍⠁", "⢋⠁", "⡋⠁", "⠍⠉", "⠋⠉", "⠋⠉", "⠉⠙", "⠉⠙", "⠉⠩", "⠈⢙", "⠈⡙", "⢈⠩", "⡀⢙", "⠄⡙", "⢂⠩", "⡂⢘", "⠅⡘", "⢃⠨", "⡃⢐", "⠍⡐", "⢋⠠", "⡋⢀", "⠍⡁", "⢋⠁", "⡋⠁", "⠍⠉", "⠋⠉", "⠋⠉", "⠉⠙", "⠉⠙", "⠉⠩", "⠈⢙", "⠈⡙", "⠈⠩", "⠀⢙", "⠀⡙", "⠀⠩", "⠀⢘", "⠀⡘", "⠀⠨", "⠀⢐", "⠀⡐", "⠀⠠", "⠀⢀", "⠀⡀"],
	["⣼", "⣹", "⢻", "⠿", "⡟", "⣏", "⣧", "⣶"],
	["⠉⠉", "⠈⠙", "⠀⠹", "⠀⢸", "⠀⣰", "⢀⣠", "⣀⣀", "⣄⡀", "⣆⠀", "⡇⠀", "⠏⠀", "⠋⠁"],
	["⢎ ", "⠎⠁", "⠊⠑", "⠈⠱", " ⡱", "⢀⡰", "⢄⡠", "⢆⡀"],
];

// zentui's working-line verb catalog, in display order.
const VERBS = [
	"Sautéing", "Cooking", "Ionizing", "Zigzagging", "Razzle-dazzling",
	"Photosynthesizing", "Nucleating", "Brewing", "Combobulating", "Boogieing",
	"Befuddling", "Alchemizing", "Conjuring", "Baking", "Simmering", "Blanching",
];

// cli-spinners' dotsCircle — every frame is exactly 2 cells (the spaces are
// load-bearing padding), so the in-progress dot never wiggles horizontally.
const DOTS_CIRCLE = ["⢎ ", "⠎⠁", "⠊⠑", "⠈⠱", " ⡱", "⢀⡰", "⢄⡠", "⢆⡀"];

type Rgb = [number, number, number];

function hexToRgbTuple(hex: string): Rgb | undefined {
	if (typeof hex !== "string" || !/^[0-9a-f]{6}$/i.test(hex)) return undefined;
	return [
		parseInt(hex.slice(0, 2), 16),
		parseInt(hex.slice(2, 4), 16),
		parseInt(hex.slice(4, 6), 16),
	];
}

// pi-animations' PI_GRAD — the fallback gradient when no base16 palette is
// available (magenta → purple → cyan).
const SHIMMER_FALLBACK: Rgb[] = [
	[255, 0, 135], [175, 95, 175], [135, 95, 215],
	[95, 95, 255], [95, 175, 255], [0, 255, 255],
];

// Gradient stops + base tone, memoized per (palette epoch, theme instance,
// color mode, stops key). base16() bumps the epoch whenever it re-reads a
// changed base16.json, so a toggle-theme mid-session recolors the shimmer on
// the next frame; themeId() keys theme-tier colors by the live Theme
// instance (swapped by /theme); stale entries are bounded (epochs only bump
// on palette changes, theme ids only on theme swaps).
const shimmerPalettes = new Map<string, { grad: Rgb[]; base: Rgb }>();
function shimmerColors(stops: readonly string[]): { grad: Rgb[]; base: Rgb } {
	refreshBase16(); // may bump the epoch — must run before the cache key
	const t = liveTheme();
	const key = `${base16Epoch()}:${themeId(t)}:${t?.getColorMode() ?? ""}:${stops.join(",")}`;
	let p = shimmerPalettes.get(key);
	if (!p) {
		// Tier 1: palette hexes. Tier 2: the live theme — RGB parsed from its
		// SGR, only in truecolor mode (256color has no honest RGB; keep static
		// fallbacks there). Tier 3: pi-animations' rainbow.
		let grad = stops
			.map(base16)
			.map((hex) => hexToRgbTuple(hex ?? ""))
			.filter((c): c is Rgb => c !== undefined);
		if (grad.length < 2 && t) {
			grad = stops.map((name) => themeNameRgb(t, name)).filter((c): c is Rgb => c !== undefined);
		}
		let base = hexToRgbTuple(base16("base04") ?? "");
		if (base === undefined && t) base = themeNameRgb(t, "base04");
		p = {
			grad: grad.length >= 2 ? grad : SHIMMER_FALLBACK,
			base: base ?? [200, 200, 200],
		};
		shimmerPalettes.set(key, p);
	}
	return p;
}

// One shimmer frame over `text`: a sine wave rides the string, and cells
// above the threshold blend from the base tone toward a gradient stop (the
// ramp position itself scrolls with the frame). Raw truecolor SGR — the
// colors come from the stylix palette, but per-character coloring is beyond
// theme.fg. `stops` names the base16 gradient (default: the batch header's
// base0D→base0E→base0C sweep).
export function shimmerFrame(
	text: string,
	frame: number,
	stops: readonly string[] = ["base0D", "base0E", "base0C"],
): string {
	const { grad, base } = shimmerColors(stops);
	let line = "";
	for (let i = 0; i < text.length; i++) {
		const wave = Math.sin((i - frame * 0.3) * 0.8);
		if (wave > 0.3) {
			const intensity = (wave - 0.3) / 0.7;
			const gi = Math.floor((i + frame * 0.5) % (grad.length * 2));
			const gIdx = gi < grad.length ? gi : grad.length * 2 - 1 - gi;
			const gc = grad[Math.min(gIdx, grad.length - 1)];
			const r = Math.round(base[0] + (gc[0] - base[0]) * intensity);
			const g = Math.round(base[1] + (gc[1] - base[1]) * intensity);
			const b = Math.round(base[2] + (gc[2] - base[2]) * intensity);
			line += `\x1b[1m\x1b[38;2;${r};${g};${b}m${text[i]}\x1b[22m`;
		} else {
			line += `\x1b[38;2;${base[0]};${base[1]};${base[2]}m${text[i]}`;
		}
	}
	return line + "\x1b[0m";
}

// Animated header for a running batch:
// `▸ Combobulating… 2s · ↑12.4k · 4 tool calls (ctrl+o to expand)`
// with the dots spinner in the accent color and the verb shimmering through
// the stylix gradient. The trailing info keeps the static header's styling.
export function liveGroupHeaderLine(
	theme: Theme,
	count: number,
	thoughtMs: number | undefined,
	frame: number,
	spinner: number,
	batchIndex: number,
	url?: string,
	diff?: { adds: number; dels: number },
	diffUrl?: string,
): string {
	const frames = DOTS_SPINNERS[spinner % DOTS_SPINNERS.length] ?? DOTS_SPINNERS[0];
	const glyph = theme.fg("accent", frames[frame % frames.length] ?? "·");
	const verb = shimmerFrame(`${VERBS[batchIndex % VERBS.length]}…`, frame);
	// Present tense while the batch runs: verb + bare timer ("Sautéing…
	// 1m 39s · ↑12.4k · 2 tool calls") — the shimmer verb already carries the
	// participle, so no "Thinking" prefix. Whole-second precision: at 0.1s
	// precision the readout aliases against repaint rate (spins fast during
	// dense text deltas, stutters when only the tick repaints) — 1Hz changes
	// resolve cleanly at any cadence. The ↑N token readout is turn-wide and
	// re-read every frame (settled total + in-flight estimate), so it climbs
	// in real time across every batch of the turn. The dots spinner + shimmer
	// verb own the glyph slot while the batch executes — the triangle yields.
	// The whole row is one click target (toggles the batch's children).
	const thoughtSeg = thoughtMs === undefined ? "" : `${Math.floor(thoughtMs / 1000)}s · `;
	const tokens = turnOutputTokens();
	const tok = tokens === undefined ? "" : `↑${formatTokens(tokens)} · `;
	const info = `${thoughtSeg}${tok}${count} tool call${count === 1 ? "" : "s"}`;
	const line = ` ${glyph} ${verb} ${theme.fg("muted", theme.italic(info))}`;
	// Same diffstat as the settled header — totals accumulate as Edits settle
	// mid-run, and the section keeps its position across the settle transition.
	let stat = "";
	if (diff && diffUrl && (diff.adds > 0 || diff.dels > 0)) {
		const body = `${theme.fg("success", `+${diff.adds}`)} ${theme.fg("error", `−${diff.dels}`)}`;
		stat = `  ${linkWrap(body, diffUrl)}`;
	}
	return `${url ? linkWrap(line, url) : line}${stat}`;
}

// ── Live turn output tokens ───────────────────────────────────
//
// The animated spinners (batch header, streaming thinking label, dead-air
// loader) carry a live `↑N` readout of how many tokens the model has output
// this turn. Provider usage is only authoritative per completed message, so
// the tracker sums provider-reported output over finished assistant messages
// (settled) and, for the message currently streaming, takes the larger of
// the partial's cumulative usage.output (Anthropic/Google report it per
// chunk) and a chars/4 estimate from the streamed deltas (OpenAI reports
// usage only on the final chunk — the estimate keeps the readout moving).
// State lives on globalThis (written by custom-ui.ts's event handlers, read
// at render time) because lib instances may be per-extension.

interface TurnTokenState {
	active: boolean;
	settled: number;
	provider: number;
	chars: number;
}

const TURN_TOKENS_KEY = "__piCustomUiTurnTokens";

function turnTokenState(): TurnTokenState {
	const w = globalThis as Record<string, unknown>;
	if (!w[TURN_TOKENS_KEY]) {
		w[TURN_TOKENS_KEY] = { active: false, settled: 0, provider: 0, chars: 0 };
	}
	return w[TURN_TOKENS_KEY] as TurnTokenState;
}

// agent_start: a new turn counts from zero.
export function resetTurnTokens(): void {
	const t = turnTokenState();
	t.active = true;
	t.settled = 0;
	t.provider = 0;
	t.chars = 0;
}

// assistant message_start: per-message accumulation starts over.
export function beginTurnMessage(): void {
	const t = turnTokenState();
	t.provider = 0;
	t.chars = 0;
}

// message_update: count streamed delta characters (any delta kind —
// thinking, text, toolcall arguments).
export function noteTurnDelta(chars: number): void {
	if (chars > 0) turnTokenState().chars += chars;
}

// message_update: the partial's provider usage is cumulative for the
// streaming message; keep the high-water mark.
export function noteTurnProviderOutput(output: number | undefined): void {
	if (typeof output !== "number" || output <= 0) return;
	const t = turnTokenState();
	if (output > t.provider) t.provider = output;
}

// message_end: the message's output joins the settled total —
// provider-reported when available, estimated otherwise (aborted streams).
export function settleTurnMessage(output: number | undefined): void {
	const t = turnTokenState();
	t.settled += output ?? Math.ceil(t.chars / 4);
	t.provider = 0;
	t.chars = 0;
}

// agent_end / session_start: no turn is running — spinners hide the readout.
export function endTurnTokens(): void {
	turnTokenState().active = false;
}

// Output tokens so far this turn, or undefined when no turn is running.
export function turnOutputTokens(): number | undefined {
	const t = turnTokenState();
	if (!t.active) return undefined;
	return t.settled + Math.max(t.provider, Math.ceil(t.chars / 4));
}

// Compact token count — same shape as the turn summary row (999 / 1.2k /
// 12k / 1.2M).
export function formatTokens(n: number): string {
	if (n < 1000) return String(n);
	if (n < 10_000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	return `${Math.round(n / 1_000_000)}M`;
}

// ── Click-to-expand: OSC 8 action links ───────────────────────
//
// Fullscreen pi captures the mouse; clicking an OSC 8 hyperlink resolves the
// link under the clicked cell from the rendered screen and calls the TUI's
// openUrl (wired to openBrowser). The extension UI context is a proxy with a
// set trap over the live renderer, so the zero-line widget capture (see
// custom-ui.ts session_start) can re-patch openUrl to intercept
// pi-action:// URLs and translate them into expansion toggles. In regular
// (non-fullscreen) mode the terminal handles hyperlinks natively and pi
// never sees the click, so links are only emitted while the patch is live.

const LINKS_KEY = "__piCustomUiLinksEnabled";

function setLinksEnabled(value: boolean): void {
	(globalThis as Record<string, unknown>)[LINKS_KEY] = value;
}

function linksEnabled(): boolean {
	return (globalThis as Record<string, unknown>)[LINKS_KEY] === true && getCapabilities().hyperlinks;
}

// Wrap a rendered string fragment in an OSC 8 hyperlink pointing at a
// pi-action:// toggle. No-op when action links are unavailable (regular
// mode, unsupported terminal, before session_start).
export function linkWrap(text: string, url: string): string {
	return linksEnabled() ? `\x1b]8;;${url}\x1b\\${text}\x1b]8;;\x1b\\` : text;
}

export interface TuiLinkHandle {
	mode?: string;
	openUrl?: (url: string) => void;
	requestRender(): void;
}

let restoreOpenUrl: (() => void) | undefined;

// Patch the TUI handle's openUrl to intercept action links. Called from the
// zero-line widget factory on session_start (the factory receives the UI
// context proxy; property writes land on the live renderer instance).
export function enableLinkActions(tui: TuiLinkHandle): void {
	disableLinkActions();
	if (tui.mode !== "fullscreen") return;
	const original = tui.openUrl;
	tui.openUrl = (url: string) => {
		if (!handleActionUrl(url)) original?.(url);
	};
	restoreOpenUrl = () => {
		tui.openUrl = original;
	};
	setLinksEnabled(true);
}

export function disableLinkActions(): void {
	restoreOpenUrl?.();
	restoreOpenUrl = undefined;
	setLinksEnabled(false);
}

// Dispatch a clicked action URL; false when the URL is not ours (the caller
// falls back to opening it in the default browser handler). URLs are tree
// paths: each flips exactly ONE node's flag.
export function handleActionUrl(url: string): boolean {
	const match = /^pi-action:\/\/node\/(batch|tool|thought|edits)\/(\S+)$/.exec(url);
	if (!match) return false;
	const [, kind, id] = match;
	if (kind === "batch") toggleBatch(Number.parseInt(id, 10));
	else if (kind === "tool") toggleTool(decodeURIComponent(id));
	else if (kind === "edits") toggleEdits(Number.parseInt(id, 10));
	else toggleThought(Number.parseInt(id, 10));
	// Row invalidations are deferred (setTimeout 0) — make sure a repaint
	// follows in every case.
	setTimeout(() => animState().requestRender?.(), 0);
	return true;
}

// ── Shared animation API (consumed by lib/thinking-fold) ─────
//
// Unification rule: exactly ONE animated "Thinking" indicator is visible at
// a time — the batch header while a batch is open (the fold then suppresses
// its own streaming thinking row; its duration already counts into the
// header), otherwise the fold's streaming label, which renders through this
// API so both rows share the spinner/shimmer design language. The fold falls
// back to its plain static label when this API is absent (custom-ui off).
// pi's native loader row is hidden during reasoning by custom-ui.ts.
//
// Colors here are raw base16 SGR (accent = base0D, muted = base04) rather
// than theme.fg: the fold has no Theme handle (its internals.theme is a
// MarkdownTheme), and under the stylix theme base0D/base04 ARE accent/muted.
// The fold's streaming label must also bypass Markdown (raw SGR would be
// mangled) — it renders the label through a pi-tui Text instead.

interface AnimApi {
	// Shared animation clock — WALL-CLOCK derived (ms/FRAME_MS since first
	// use), so animation speed is independent of tick/repaint cadence. Heavy
	// streaming delays repaints, but every repaint shows the frame the wall
	// clock says: perceived speed stays constant.
	readonly frame: number;
	// Clock origin (set once at first use).
	t0: number;
	// True while a tool batch is open (track→collapse). Read by the fold's
	// rebuild() to decide whether its streaming thinking row should exist.
	batchOpen: boolean;
	// Injected by custom-ui.ts on session_start (zero-line widget capture,
	// same trick as the anim widget below): forces a TUI repaint. Animation
	// timers MUST call this per tick — rebuilding children alone doesn't
	// repaint, and with the native loader hidden there's no spinner loop
	// pumping frames between streaming deltas (the frozen-label bug).
	requestRender?(): void;
	// Accent-colored dots spinner frame, varied by seed.
	spinnerFrame(seed: number): string;
	// Accent-colored dotsCircle frame for in-progress tool-call dots.
	inProgressDot(): string;
	// Animated streaming-thinking label (always animated — the batch header
	// yields while thinking streams, so this row is always the one spinner):
	// `▸ Combobulating… 2s · ↑1.2k  (ctrl+t to expand)`. `url` wraps the whole
	// label in a pi-action://node/thought OSC 8 link (click-to-expand).
	streamingLabel(seconds: string, canExpand: boolean, expandSuffix: string, seed: number, url?: string): string;
	// Settled completed-thinking label (the fold row after the thinking
	// ends): base03 bold per user spec.
	completedLabel(seconds: string, canExpand: boolean, expandSuffix: string, url?: string): string;
	// Full accent-tinted frame set for a dots variant — for consumers that
	// own their animation interval (e.g. pi's setWorkingIndicator).
	accentSpinnerFrames(seed: number): string[];
	// Animated dead-air loader text: `{dots} {shimmer verb…} ↑N` (N = live
	// turn output tokens). Driven per-tick
	// by the consumer through setWorkingMessage — pi's own indicator animation
	// proved unreliable mid-turn, so the message carries the motion.
	loaderLabel(seed: number): string;
	tick(): number;
}

const ANIM_KEY = "__piCustomUiAnim";

// Animation frame duration (ms) — the cli-spinners dots family's default
// cadence.
const FRAME_MS = 80;

function accentSgr(): string {
	return base16Fg("base0D", "5dafd4");
}

export function animState(): AnimApi {
	const w = globalThis as Record<string, unknown>;
	if (!w[ANIM_KEY]) {
		w[ANIM_KEY] = {
			t0: Date.now(),
			batchOpen: false,
			get frame() {
				return Math.floor((Date.now() - this.t0) / FRAME_MS);
			},
			spinnerFrame(seed: number) {
				const frames = DOTS_SPINNERS[Math.abs(seed) % DOTS_SPINNERS.length] ?? DOTS_SPINNERS[0];
				const glyph = frames[this.frame % frames.length] ?? "·";
				// base0D — the theme accent under stylix (see base16Fg fallbacks).
				return `${accentSgr()}${glyph}\x1b[39m`;
			},
			completedLabel(seconds: string, canExpand: boolean, expandSuffix: string, url?: string) {
				const base03 = base16Fg("base03", "6a737d");
				const tail = canExpand ? expandSuffix : "";
				const core = `\x1b[1m${base03}Thought for ${seconds}${tail}\x1b[22m\x1b[39m`;
				return url ? linkWrap(core, url) : core;
			},
			accentSpinnerFrames(seed: number) {
				const frames = DOTS_SPINNERS[Math.abs(seed) % DOTS_SPINNERS.length] ?? DOTS_SPINNERS[0];
				const accent = accentSgr();
				return frames.map((f) => `${accent}${f}\x1b[39m`);
			},
			loaderLabel(seed: number) {
				const tokens = turnOutputTokens();
				const tok = tokens === undefined ? "" : ` ${base16Fg("base04", "8a9199")}↑${formatTokens(tokens)}\x1b[39m`;
				return `${this.spinnerFrame(seed)} ${shimmerFrame(`${VERBS[Math.abs(seed) % VERBS.length]}…`, this.frame)}${tok}`;
			},
			inProgressDot() {
				const glyph = DOTS_CIRCLE[this.frame % DOTS_CIRCLE.length] ?? "●";
				return `${accentSgr()}${glyph}\x1b[39m`;
			},
			streamingLabel(seconds: string, canExpand: boolean, expandSuffix: string, seed: number, url?: string) {
				const verb = shimmerFrame(`${VERBS[Math.abs(seed) % VERBS.length]}…`, this.frame);
				const muted = base16Fg("base04", "8a9199");
				const tokens = turnOutputTokens();
				const tok = tokens === undefined ? "" : ` · ↑${formatTokens(tokens)}`;
				const tail = canExpand ? expandSuffix : "";
				const core = `${this.spinnerFrame(seed)} ${verb} ${muted}${seconds}${tok}${tail}\x1b[0m`;
				return url ? linkWrap(core, url) : core;
			},
			tick(this: AnimApi) {
				// The clock advances by itself (wall clock); a tick is only
				// meaningful as "a repaint request follows". Kept for API shape.
				return this.frame;
			},
		} satisfies AnimApi;
	}
	return w[ANIM_KEY] as AnimApi;
}

function setBatchOpen(open: boolean): void {
	animState().batchOpen = open;
}

// Initialize eagerly so the fold sees the API (and batchOpen = false) even
// before the first tool call.
animState();

// ── Terminal theme (base16) colors ────────────────────────────
//
// home-modules/extra/ai/pi/default.nix renders the stylix base16 scheme to
// ~/.pi/agent/extensions/lib/base16.json, so TUI colors here can follow the
// terminal theme instead of being hardcoded. Cached on globalThis (this lib
// is loaded by several independent extension module instances), re-read when
// possibly stale (throttled) and compared by CONTENT — store mtimes are
// canonicalized (mtime=1) and dark/light files are byte-equal in size, so a
// stat signature cannot detect a toggle-theme symlink swap. A missing/
// unreadable file falls back to the Ayu Dark defaults.
// The cache key is versioned: /reload keeps globalThis across extension
// reloads, so a cache written by an older lib shape must be ignored (a
// shape mismatch here silently poisoned lookups after /reload).
const BASE16_PATH = join(homedir(), ".pi/agent/extensions/lib/base16.json");
const BASE16_TTL_MS = 500;
const BASE16_CACHE_KEY = "__piCustomUiBase16CacheV2";
interface Base16Cache {
	palette: Record<string, string>;
	raw: string;
	checkedAt: number;
}
const base16State = globalThis as Record<string, unknown>;

function base16Epoch(): number {
	return (base16State.__piCustomUiBase16Epoch as number | undefined) ?? 0;
}

// Throttled re-check of base16.json: re-reads (and bumps the epoch) when the
// file's content changed. Callers that DERIVE cache keys from the epoch must
// call this first — the epoch only moves during a refresh.
function refreshBase16(): void {
	const cached = base16State[BASE16_CACHE_KEY] as Base16Cache | undefined;
	const valid = cached !== undefined && typeof cached.checkedAt === "number";
	if (!valid || Date.now() - cached!.checkedAt >= BASE16_TTL_MS) {
		try {
			const raw = readFileSync(BASE16_PATH, "utf8");
			if (!valid || raw !== cached!.raw) {
				base16State.__piCustomUiBase16Epoch = base16Epoch() + 1;
				base16State[BASE16_CACHE_KEY] = {
					palette: JSON.parse(raw),
					raw,
					checkedAt: Date.now(),
				};
			} else {
				cached!.checkedAt = Date.now();
			}
		} catch {
			if (!valid) {
				base16State[BASE16_CACHE_KEY] = {
					palette: {},
					raw: "",
					checkedAt: Date.now(),
				};
			}
			// Unreadable later on (e.g. transient swap state): keep the old palette.
		}
	}
}

function base16(name: string): string | undefined {
	refreshBase16();
	const entry = base16State[BASE16_CACHE_KEY] as Base16Cache;
	return entry.palette[name];
}

// ── Live-theme tier ───────────────────────────────────────────────
// ctx.ui.theme is a live getter over pi's theme module singleton, so a source
// that re-reads it tracks /theme changes with no event hook. The registration
// lives on globalThis (lib instances are per-extension); custom-ui.ts's
// session_start (the first ctx-bearing event) publishes it, and every lib
// instance then resolves through the shared source. When unregistered, this
// tier is simply skipped and the static Ayu fallback applies.
type ThemeSource = () => Theme | undefined;

export function setLiveThemeSource(getTheme: ThemeSource | undefined): void {
	(globalThis as Record<string, unknown>).__piCustomUiThemeSource = getTheme;
}

function liveTheme(): Theme | undefined {
	const get = (globalThis as Record<string, unknown>).__piCustomUiThemeSource as
		| ThemeSource
		| undefined;
	if (get === undefined) return undefined;
	try {
		return get();
	} catch {
		return undefined;
	}
}

// Per-instance identity for cache keys — /theme swaps the Theme instance, and
// the same-named theme file can also be reloaded (bumping name+mode strings
// would miss that).
const themeIds = new WeakMap<Theme, number>();
let nextThemeId = 1;
function themeId(t: Theme | undefined): number {
	if (t === undefined) return 0;
	let id = themeIds.get(t);
	if (id === undefined) {
		id = nextThemeId++;
		themeIds.set(t, id);
	}
	return id;
}

// base16 name → live-theme roles, tried in order: getFgAnsi/getBgAnsi THROW
// on absent colors (the thinking*/search* slots are optional), so the next
// role is tried. Only names the suite actually uses are mapped. Palette hexes
// win first (tier 1); this is tier 2; static Ayu hexes are tier 3.
const THEME_FG_ROLES: Record<string, readonly string[]> = {
	base03: ["syntaxComment", "muted"],
	base04: ["muted", "toolOutput"],
	base08: ["error"],
	base09: ["thinkingMax", "warning"], // orange — no direct role; thinkingMax is optional
	base0A: ["warning"],
	base0B: ["success"],
	base0C: ["thinkingLow", "mdCode"],
	base0D: ["accent", "mdLink"],
	base0E: ["customMessageLabel", "thinkingHigh"],
};
const THEME_BG_ROLES: Record<string, readonly string[]> = {
	// The band backgrounds must flip with the theme's polarity (light theme →
	// light band): the dark Ayu fallback is what made light terminals unreadable.
	base01: ["userMessageBg", "customMessageBg", "selectedBg"],
};

// Truecolor SGR → RGB tuple (theme.getFgAnsi output). Undefined for other
// color modes (256color gradients have no honest RGB) or unparseable colors.
function themeFgRgb(t: Theme, name: string): Rgb | undefined {
	if (t.getColorMode() !== "truecolor") return undefined;
	try {
		const m = /\x1b\[38;2;(\d+);(\d+);(\d+)m/.exec(t.getFgAnsi(name as Parameters<Theme["getFgAnsi"]>[0]));
		return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : undefined;
	} catch {
		return undefined;
	}
}

// RGB tuple for a base16 NAME via the live theme: walks the name's role
// chain (themeFgRgb returns undefined per role; absent colors throw). Used
// where raw RGB is needed (the shimmer gradient/base tone) instead of SGR.
function themeNameRgb(t: Theme, name: string): Rgb | undefined {
	for (const role of THEME_FG_ROLES[name] ?? []) {
		const rgb = themeFgRgb(t, role);
		if (rgb !== undefined) return rgb;
	}
	return undefined;
}

// SGR foreground for a base16 color (hex without '#'). Three tiers: the
// base16.json palette (stylix — exact scheme), the live pi theme (the
// theme's own SGR for the mapped role, correct for the terminal's color
// mode), then the Ayu Dark `fallbackHex` (theme-less installs).
export function base16Fg(name: string, fallbackHex: string): string {
	const hex = base16(name);
	if (typeof hex === "string" && /^[0-9a-f]{6}$/i.test(hex)) {
		const n = parseInt(hex, 16);
		return `\x1b[38;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
	}
	const t = liveTheme();
	if (t !== undefined) {
		for (const role of THEME_FG_ROLES[name] ?? []) {
			try {
				return t.getFgAnsi(role as Parameters<Theme["getFgAnsi"]>[0]);
			} catch {
				// Optional color absent — try the next role.
			}
		}
	}
	const n = parseInt(fallbackHex, 16);
	return `\x1b[38;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
}

// SGR background for a base16 color; same three tiers as base16Fg.
export function base16Bg(name: string, fallbackHex: string): string {
	const hex = base16(name);
	if (typeof hex === "string" && /^[0-9a-f]{6}$/i.test(hex)) {
		const n = parseInt(hex, 16);
		return `\x1b[48;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
	}
	const t = liveTheme();
	if (t !== undefined) {
		for (const role of THEME_BG_ROLES[name] ?? []) {
			try {
				return t.getBgAnsi(role as Parameters<Theme["getBgAnsi"]>[0]);
			} catch {
				// Optional color absent — try the next role.
			}
		}
	}
	const n = parseInt(fallbackHex, 16);
	return `\x1b[48;2;${(n >> 16) & 0xff};${(n >> 8) & 0xff};${n & 0xff}m`;
}

// One-line collapsed child: `├─ Bash(cmd) · 51 lines`. The call head recedes
// to base03 (comments grey, from the base16 palette) so color is reserved
// for signal — exit codes, diffs, and pre-colored summaries. The row is the
// primary click-to-expand target.
export function glanceLine(label: string, arg: string, summary: string, theme: Theme, mode?: GroupMode, toolCallId?: string): Text {
	const base03 = base16Fg("base03", TREE_BASE03);
	const glyph = mode?.kind === "child" ? childLabelGlyph(mode.last) : "";
	const head = `${base03}${label}(${clip(arg, 56)})\x1b[39m`;
	const core = `${glyph}${head} · ${summary}`;
	const url = toolCallId ? `pi-action://node/tool/${encodeURIComponent(toolCallId)}` : undefined;
	return new Text(url ? linkWrap(core, url) : core, 0, 0);
}

// ── Tree interaction: toggles, ctrl+o walk, fold renderer ──
//
// Action URLs are tree paths, each flipping exactly ONE node's flag:
// - pi-action://node/batch/<i> — the header row (toggle depth 2)
// - pi-action://node/tool/<id> — a glance/call row (toggle depth 3 output)
// - pi-action://node/thought/<ts> — a thought branch/row (toggle depth 3)
// The URLs are emitted as OSC 8 hyperlinks and resolved by pi's fullscreen
// mouse handling (see enableLinkActions below).

// Toggle a batch header: open/close all its children. Collapsing a RUNNING
// batch is sticky — it wins over the auto-open until the user re-opens (or a
// new batch starts and this one settles). A SOLO batch (exactly one tool
// call) toggles that call's output in the same gesture — one click expands
// the whole block. Edits are the exception: the diffstat owns their expansion.
export function toggleBatch(batchIndex: number): void {
	const s = groupState();
	const batch = s.batches[batchIndex];
	if (!batch) return;
	if (batchOpen(batch)) {
		batch.open = false;
		batch.stickyClosed = true;
	} else {
		batch.open = true;
		batch.stickyClosed = false;
	}
	// A SOLO batch of exactly ONE node (one tool call, no reasoning block)
	// toggles that call's output in the same gesture — one click expands the
	// whole block. Anything bigger (a thought branch, multiple tools) grows
	// node by node via its own click targets. Edits are excluded regardless:
	// their output starts expanded ONLY via the header diffstat click, the
	// dedicated affordance for "show me what changed".
	batch.editsOpenedHeader = undefined;
	if (batch.ids.length === 1 && batch.thoughts.length === 0 && !s.editIds.has(batch.ids[0])) {
		const id = batch.ids[0];
		if (batchOpen(batch)) {
			s.openTools.add(id);
			s.closedTools.delete(id);
		} else {
			s.openTools.delete(id);
			s.closedTools.add(id);
		}
	}
	invalidateRows(batch.ids);
	invalidateThoughtRows(batch.thoughts);
}

// Toggle the batch's Edit calls' output as one — the header diffstat's click
// action. If any edit row is currently expanded, close them all; otherwise
// open them all (uncapped — a deliberate expansion). Per-row defaults apply
// again after a ctrl+o walk or an individual row toggle dissolves the flag.
export function toggleEdits(batchIndex: number): void {
	const s = groupState();
	const batch = s.batches[batchIndex];
	if (!batch) return;
	const editIds = batch.ids.filter((id) => s.editIds.has(id));
	if (editIds.length === 0) return;
	const anyOpen = editIds.some((id) => {
		const mode = groupMode(id);
		return mode.kind === "child" && mode.outputOpen;
	});
	batch.editsOpen = !anyOpen;
	// The diffstat is a FULL toggle: expanding from it opens the header too
	// (see the changes without a second click), and the second click
	// collapses the tree back the way it was. A header the user opened
	// themselves survives diff-close.
	if (batch.editsOpen) {
		if (!batchOpen(batch)) {
			batch.open = true;
			batch.stickyClosed = false;
			batch.editsOpenedHeader = true;
		}
	} else if (batch.editsOpenedHeader) {
		batch.open = false;
		batch.stickyClosed = true;
		batch.editsOpenedHeader = undefined;
	}
	invalidateRows(batch.ids);
	invalidateThoughtRows(batch.thoughts);
}

// Toggle one child's depth-3 output. Closing the auto-opened newest child
// must stick, so the explicit close lands in closedTools (beats the
// positional auto-open).
export function toggleTool(toolCallId: string): void {
	const s = groupState();
	const mode = groupMode(toolCallId);
	if (mode.kind !== "child") return;
	// An individual row click dissolves the batch-wide edit override — per-row
	// intent takes over from here on.
	const idx = s.memberBatch.get(toolCallId);
	const batch = idx !== undefined ? s.batches[idx] : undefined;
	if (batch && s.editIds.has(toolCallId)) batch.editsOpen = undefined;
	if (mode.outputOpen) {
		s.openTools.delete(toolCallId);
		s.closedTools.add(toolCallId);
	} else {
		s.openTools.add(toolCallId);
		s.closedTools.delete(toolCallId);
	}
	invalidateRows([toolCallId]);
}

// Toggle one thought branch's depth-3 reasoning.
export function toggleThought(timestamp: number): void {
	const s = groupState();
	if (s.openThoughts.has(timestamp)) s.openThoughts.delete(timestamp);
	else s.openThoughts.add(timestamp);
	invalidateThoughtRows([timestamp]);
}

// ctrl+o = full expand/collapse: walk every node, set all flags. Exact tree
// semantics replace the old global-flag observer: expand-all opens every
// header and every child; collapse-all clears them (running batches become
// sticky-closed so the auto-open doesn't win back).
export function walkTree(expand: boolean): void {
	const s = groupState();
	for (const batch of s.batches) {
		batch.open = expand;
		batch.stickyClosed = !expand && batch.running;
		batch.editsOpen = undefined;
		batch.editsOpenedHeader = undefined;
	}
	s.openTools.clear();
	s.closedTools.clear();
	s.openThoughts.clear();
	if (expand) {
		for (const batch of s.batches) {
			for (const id of batch.ids) s.openTools.add(id);
			for (const ts of batch.thoughts) s.openThoughts.add(ts);
		}
	}
	for (const batch of s.batches) {
		invalidateRows(batch.ids);
		invalidateThoughtRows(batch.thoughts);
	}
}

// pi drives ctrl+o through ToolExecutionComponent#setExpanded for every tool
// row in one pass; walk once per gesture, not per row.
// pi's global ctrl+o flag (ToolExecutionComponent#setExpanded) is synced to
// EVERY tool row with its CURRENT value — including `false` (the default) on
// each new component mid-stream. Only a CHANGE of the flag is a user
// gesture; walking on the per-row syncs would sticky-close the running
// batch the moment its second tool's component was created (children
// vanished under a live header).
let lastExpandedFlag = false;
function walkFromCtrlO(expand: boolean): void {
	if (expand === lastExpandedFlag) return;
	lastExpandedFlag = expand;
	walkTree(expand);
}

const TOOL_EXPAND_PATCHED = Symbol.for("pi-custom-ui/tool-expand-walk");

export function installToolExpandWalk(): void {
	const prototype = ToolExecutionComponent.prototype as unknown as Record<PropertyKey, unknown>;
	if (typeof prototype.setExpanded !== "function" || prototype[TOOL_EXPAND_PATCHED]) return;
	prototype[TOOL_EXPAND_PATCHED] = true;
	const originalSetExpanded = prototype.setExpanded as (this: unknown, expanded: boolean) => void;
	prototype.setExpanded = function (expanded: boolean) {
		walkFromCtrlO(expanded === true);
		originalSetExpanded.call(this, expanded);
	};
}

// pi's ToolExecutionComponent.render frames every self-shell tool row with a
// blank line above it (`lines.push("")` before the content). Between the
// tree view's stacked glance rows that reads as a stray gap after every
// child, so drop it — the prototype-patch replacement for the postFixup sed
// the pkgs/alias.nix override used to carry. Prototype level covers every
// self-shell row the sed covered: live streaming, restored transcripts, and
// the untracked pre-bind first passes.
// Newer upstream also routes clicks through handleMouse with a +1 y-offset
// that assumes the framing blank; shift events back into its coordinates so
// clicks stay aligned once the blank is gone. Feature-detected: 0.84.x has
// no handleMouse yet.
const TOOL_RENDER_PATCHED = Symbol.for("pi-custom-ui/tool-exec-render");

export function installTightSelfRows(): void {
	const prototype = ToolExecutionComponent.prototype as unknown as Record<PropertyKey, unknown>;
	if (typeof prototype.render !== "function" || prototype[TOOL_RENDER_PATCHED]) return;
	prototype[TOOL_RENDER_PATCHED] = true;
	// hasRendererDefinition/getRenderShell/imageComponents are TS-private on
	// ToolExecutionComponent; intersecting collapses the type to never (same
	// trap as the Loader patch), so patch through a plain structural view.
	type ToolExecView = {
		hasRendererDefinition(): boolean;
		getRenderShell(): string;
		imageComponents?: unknown[];
	};
	const originalRender = prototype.render as (this: ToolExecView, width: number) => string[];
	prototype.render = function (this: ToolExecView, width: number) {
		const lines = originalRender.call(this, width);
		// The framing blank is pushed iff contentLines.length > 0; the only
		// other way a self-shell row starts blank is an image spacer above
		// empty content, excluded via imageComponents. Our renderers never
		// begin a row with a blank line, so a leading blank here is always
		// pi's framing.
		if (
			lines.length > 0 &&
			lines[0].trim() === "" &&
			!this.imageComponents?.length &&
			this.hasRendererDefinition() &&
			this.getRenderShell() === "self"
		) {
			return lines.slice(1);
		}
		return lines;
	};
	if (typeof prototype.handleMouse === "function") {
		type MouseEvt = { y: number } & Record<string, unknown>;
		const originalHandleMouse = prototype.handleMouse as (
			this: ToolExecView,
			event: MouseEvt,
		) => unknown;
		prototype.handleMouse = function (this: ToolExecView, event: MouseEvt) {
			if (!(this.hasRendererDefinition() && this.getRenderShell() === "self")) {
				return originalHandleMouse.call(this, event);
			}
			// handleMouse still subtracts 1 (blank-line space); shift events
			// down one so y-1 lands back on the row the user clicked.
			return originalHandleMouse.call(this, { ...event, y: event.y + 1 });
		};
	}
}

// ── Tree-renderer API (consumed by lib/thinking-fold) ──────
//
// The thinking-fold renderer always renders thinking as rows; it consults
// two signals per timestamp — branchScope(ts) (depth-1 branch vs standalone)
// and the scope's headerOpen flag (parent header open) — and builds branch
// labels, content connectors, and the anchor's header line through the
// helpers here. These used to cross a package boundary over a globalThis
// channel (__piCustomUiTree); thinking-fold now lives in this suite
// (lib/thinking-fold/) and imports them directly.

export type BranchScope =
	| { kind: "standalone"; contentOpen: boolean }
	| {
			kind: "branch";
			batchIndex: number;
			last: boolean;
			headerOpen: boolean;
			contentOpen: boolean;
	  }
	| {
			kind: "anchor";
			batchIndex: number;
			last: boolean;
			headerOpen: boolean;
			contentOpen: boolean;
			running: boolean;
			count: number;
	  };

export function branchScope(ts: number | undefined): BranchScope {
	const s = groupState();
	const contentOpen = ts !== undefined && s.openThoughts.has(ts);
	if (ts === undefined) return { kind: "standalone", contentOpen };
	const idx = s.thoughtBatch.get(ts);
	if (idx === undefined) return { kind: "standalone", contentOpen };
	const batch = s.batches[idx];
	if (!batch) return { kind: "standalone", contentOpen };
	const lastChild = batch.children[batch.children.length - 1];
	const last = lastChild?.kind === "thought" && lastChild.ts === ts;
	const common = { batchIndex: idx, last, headerOpen: batchOpen(batch), contentOpen };
	if (batch.anchor === ts) {
		return { kind: "anchor", ...common, running: batch.running, count: batch.ids.length };
	}
	return { kind: "branch", ...common };
}

// Themeless header line for the anchor row (the fold's internals.theme is a
// MarkdownTheme; the line builders fall back to the base16 palette).
const SYNTHETIC_THEME = {
	italic: (t: string) => `\x1b[3m${t}\x1b[23m`,
	bold: (t: string) => `\x1b[1m${t}\x1b[22m`,
	fg: (color: string, t: string) => {
		const map: Record<string, [string, string]> = {
			accent: ["base0D", "5dafd4"],
			muted: ["base04", "8a9199"],
			success: ["base0B", "26a269"],
			error: ["base08", "c01c28"],
		};
		const hit = map[color];
		return hit ? `${base16Fg(hit[0], hit[1])}${t}\x1b[39m` : t;
	},
} as unknown as Theme;

// Batch diffstat: summed +added/−removed lines over every settled Edit call
// in the batch (editStats fills in as edit results land — history restore
// included, since the slots run there too). Undefined while nothing has
// settled; the header omits the section until there is something to show.
function batchDiffTotals(batch: TreeBatch): { adds: number; dels: number } | undefined {
	const s = groupState();
	let adds = 0;
	let dels = 0;
	let seen = false;
	for (const id of batch.ids) {
		const stat = s.editStats.get(id);
		if (stat) {
			adds += stat.adds;
			dels += stat.dels;
			seen = true;
		}
	}
	return seen ? { adds, dels } : undefined;
}

// The batch header line (`▸/▾ …` settled, live spinner+shimmer while
// running), link-wrapped with the batch toggle URL. Rendered by the anchor
// think's row for thinking-anchored batches.
export function forkBatchHeaderLine(batchIndex: number): string | undefined {
	const batch = groupState().batches[batchIndex];
	if (!batch) return undefined;
	const thoughtMs = thoughtForMs(batch.thoughts);
	const url = `pi-action://node/batch/${batchIndex}`;
	const diff = batchDiffTotals(batch);
	const diffUrl = `pi-action://node/edits/${batchIndex}`;
	return batch.running
		? liveGroupHeaderLine(SYNTHETIC_THEME, batch.ids.length, thoughtMs, animState().frame, batch.spinner, batchIndex, url, diff, diffUrl)
		: groupHeaderLine(SYNTHETIC_THEME, batch.ids.length, thoughtMs, batchOpen(batch), url, diff, diffUrl);
}

export function forkThoughtGlyph(last: boolean): string {
	return childLabelGlyph(last);
}

// Content connector for a thought branch: `│  ` when siblings follow (the
// through-connector links its corner past its content to the next sibling),
// 3 spaces for the last child (the corner already turned) — and for
// standalone thoughts, whose content indents 3 cells with no connector.
export function forkThoughtConnector(last: boolean): string {
	return last ? "    " : ` ${base16Fg("base03", TREE_BASE03)}│\x1b[39m  `;
}

export function forkStaticLabel(text: string): string {
	const base03 = base16Fg("base03", "6a737d");
	return `\x1b[1m${base03}${text}\x1b[22m\x1b[39m`;
}

// The fold registers a per-timestamp invalidator on first render so tree
// state changes (anchor assignment, open/close, ╰→├─ reglyphing,
// tick-driven header animation) re-render thought rows.
export function registerThoughtRow(timestamp: number, invalidate: () => void): void {
	groupState().thoughtRows.set(timestamp, invalidate);
}

// ── Tree-aware slot helpers ─────────────────────────────────
//
// renderCall: hidden rows render nothing; the first child of a bare batch
// carries the header (a collapsed header IS the row); an open child renders
// its call line (the collapse click target) — the header stacked above it
// when it is also the carrier.
export function treeCall(mode: GroupMode, theme: Theme, context: any, call: () => Component): Component {
	trackRow(context);
	if (mode.kind !== "child") return call();
	const carriesHeader = mode.first && !mode.anchorHosted;
	if (!mode.headerOpen) {
		if (carriesHeader) {
			const line = forkBatchHeaderLine(mode.batchIndex);
			if (line) return new Text(`\n${line}`, 0, 0);
		}
		// No visible content — an empty Container renders zero lines, whereas
		// an empty Text would leave stray blank lines between hidden rows.
		return new Container();
	}
	const stack = new Container();
	if (carriesHeader) {
		const line = forkBatchHeaderLine(mode.batchIndex);
		if (line) stack.addChild(new Text(`\n${line}`, 0, 0));
	}
	// The call row renders when the output is open OR while the tool is
	// still streaming — a running tool must stay visible (its glance row
	// only exists once results arrive); showing the one-line call is not
	// an expansion. The 16-line output block is what auto-open controls.
	if (mode.outputOpen || context?.isPartial === true) stack.addChild(call());
	return stack;
}

// ---------------------------------------------------------------------------
// bash — success collapses to the first output line; errors collapse to the
// exit code plus the last output line (where the useful part usually is).
// Pi appends "Command exited with code N" to the output text of failed runs.
// ---------------------------------------------------------------------------

export const bash: RenderSlots = withToolNotes({
	renderShell: "self",
	renderCall(args, theme, context) {
		const mode = groupMode(context?.toolCallId);
		return treeCall(mode, theme, context, () => {
			const timeout = args.timeout ? theme.fg("muted", ` (timeout ${args.timeout}s)`) : "";
			return callLine("Bash", args.command ?? "", theme, timeout, mode, context);
		});
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		if (mode.kind === "child" && !mode.headerOpen) {
			// Hidden child (parent header closed): still settle the status so a
			// later re-open shows the right dot.
			if (!isPartial) settleStatus(context, context.isError);
			return new Container();
		}
		const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
		const text = resultText(result);
		if (isPartial && !context.isError) {
			if (mode.kind === "child" && !expandedNow) return new Container();
			if (!expandedNow) {
				const live = lastLine(text);
				return glanceLine("Bash", args.command ?? "", live ? `Running… ${clip(live, 80)}` : "Running…", theme, mode, context?.toolCallId);
			}
			return liveStream(text, theme, mode, toolToggleUrl(context));
		}
		settleStatus(context, context.isError);
		if (!expandedNow) {
			const lineCount = text.split("\n").filter((l) => l.trim()).length;
			const exit = text.match(/Command exited with code (\d+)/);
			const summary = context.isError
				? theme.fg("error", exit ? `exit ${exit[1]}` : "failed")
				: theme.fg("dim", lineCount > 0 ? `${lineCount} lines` : "done");
			return glanceLine("Bash", args.command ?? "", summary, theme, mode, context?.toolCallId);
		}
		if (context.isError) {
			return expandedBlock(text, theme, true, outputCap(mode), mode, toolToggleUrl(context));
		}
		return expandedBlock(text, theme, false, outputCap(mode), mode, toolToggleUrl(context));
	},
});

// ---------------------------------------------------------------------------
// read — `path:12-40` range suffix, "N lines" summary. Call and text half of
// the result are exported separately so image-history.ts (which owns `read`
// and appends inline image cells to the row) can compose them.
// ---------------------------------------------------------------------------

export function readCallSlot(args: any, theme: Theme, context?: any): Component {
	const mode = groupMode(context?.toolCallId);
	return treeCall(mode, theme, context, () => {
		let arg = shortenPath(args.path ?? "");
		if (args.offset !== undefined || args.limit !== undefined) {
			const start = args.offset ?? 1;
			arg += theme.fg("muted", `:${start}${args.limit !== undefined ? `-${start + args.limit - 1}` : ""}`);
		}
		return callLine("Read", arg, theme, "", mode, context);
	});
}

export function readTextResult(
	result: any,
	{ expanded, isPartial }: any,
	theme: Theme,
	cap?: number,
	mode?: GroupMode,
	url?: string,
): Component {
	if (isPartial) return mode?.kind === "child" ? new Container() : resultLine(theme, "Reading…", false, mode);
	const text = resultText(result);
	if (!text) return new Text("", 0, 0);
	if (expanded) {
		return expandedBlock(text, theme, false, cap, mode, url);
	}
	return resultLine(theme, `${text.split("\n").length} lines${truncationNote(result.details, theme)}`, false, mode);
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

// Record a settled edit's diffstat for the batch header's +N −M section, and
// make sure the header repaints with it: the header renders above the edit
// rows and has usually already drawn by the time the first Edit settles.
// History restores flow through here too (the slots run on restore).
function registerEditStats(context: any, result: any): void {
	const id = context?.toolCallId;
	if (!id) return;
	const s = groupState();
	s.editIds.add(id);
	const diff: string | undefined = result?.details?.diff;
	if (context.isError || !diff) return;
	const { adds, dels } = diffStats(diff);
	const prev = s.editStats.get(id);
	if (prev && prev.adds === adds && prev.dels === dels) return;
	s.editStats.set(id, { adds, dels });
	const idx = s.memberBatch.get(id);
	if (idx !== undefined) {
		invalidateRows(s.batches[idx].ids);
		invalidateThoughtRows(s.batches[idx].thoughts);
	}
}

export const edit: RenderSlots = withToolNotes({
	renderShell: "self",
	renderCall(args, theme, context) {
		// Register before groupMode so the batch-wide editsOpen override
		// applies from the row's very first render.
		if (context?.toolCallId) groupState().editIds.add(context.toolCallId);
		const mode = groupMode(context?.toolCallId);
		return treeCall(mode, theme, context, () => {
			const count = Array.isArray(args.edits) ? args.edits.length : 0;
			const suffix = count > 1 ? theme.fg("muted", ` (${count} edits)`) : "";
			return callLine("Edit", shortenPath(args.path ?? ""), theme, suffix, mode, context);
		});
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		// Register the diffstat BEFORE the hidden-child short circuit — a
		// settled (header-closed) batch's collapsed header is exactly where
		// the +N −M section must appear.
		if (!isPartial) registerEditStats(context, result);
		if (mode.kind === "child" && !mode.headerOpen) {
			// Hidden child: still settle the status for a later re-open.
			if (!isPartial) settleStatus(context, context.isError);
			return new Container();
		}
		const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
		if (isPartial && !expandedNow) {
			// Child mode: the call row is already visible while streaming.
			if (mode.kind === "child") return new Container();
			return glanceLine("Edit", shortenPath(args.path ?? ""), theme.fg("dim", "editing…"), theme, mode, context?.toolCallId);
		}
		settleStatus(context, context.isError);
		if (!expandedNow) {
			const diff: string | undefined = result.details?.diff;
			let summary = theme.fg("dim", "applied");
			if (context.isError) summary = theme.fg("error", clip(firstLine(resultText(result)) || "failed", 40));
			else if (diff) {
				const { adds, dels } = diffStats(diff);
				summary = `${theme.fg("success", `+${adds}`)} ${theme.fg("error", `−${dels}`)}`;
			}
			return glanceLine("Edit", shortenPath(args.path ?? ""), summary, theme, mode, context?.toolCallId);
		}
		const text = resultText(result);
		if (context.isError) {
			// Expanded views show the full error (Text word-wraps).
			return expandedBlock(text || "error", theme, true, outputCap(mode), mode, toolToggleUrl(context));
		}
		const diff: string | undefined = result.details?.diff;
		if (!diff) return resultLine(theme, "Applied", false, mode);
		const colored = withMore(diff, outputCap(mode) ?? MAX_EXPANDED_DIFF_LINES, theme)
			.split("\n")
			.map((line) => {
				if (line.startsWith("+") && !line.startsWith("+++")) return theme.fg("success", line);
				if (line.startsWith("-") && !line.startsWith("---")) return theme.fg("error", line);
				return theme.fg("muted", line);
			})
			.join("\n");
		const prefix = childOutputPrefix(mode, theme);
		const diffBlock = new PrefixedText(colored, prefix, mode.kind === "child" ? prefix : GLANCE_INDENT);
		const editUrl = toolToggleUrl(context);
		return editUrl ? new ClickToggle(diffBlock, editUrl) : diffBlock;
	},
});

// ---------------------------------------------------------------------------
// write — line count from the call args (the result carries no size info).
// ---------------------------------------------------------------------------

export const write: RenderSlots = {
	renderShell: "self",
	renderCall(args, theme, context) {
		const mode = groupMode(context?.toolCallId);
		return treeCall(mode, theme, context, () => {
			const lines = typeof args.content === "string" ? args.content.split("\n").length : 0;
			const suffix = lines > 0 ? theme.fg("muted", ` (${lines} lines)`) : "";
			return callLine("Write", shortenPath(args.path ?? ""), theme, suffix, mode, context);
		});
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const args = context.args ?? {};
		const mode = groupMode(context?.toolCallId);
		if (mode.kind === "child" && !mode.headerOpen) {
			// Hidden child: still settle the status for a later re-open.
			if (!isPartial) settleStatus(context, context.isError);
			return new Container();
		}
		const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
		if (isPartial && !expandedNow) {
			if (mode.kind === "child") return new Container();
			return glanceLine("Write", shortenPath(args.path ?? ""), theme.fg("dim", "writing…"), theme, mode, context?.toolCallId);
		}
		settleStatus(context, context.isError);
		if (!expandedNow) {
			const summary = context.isError
				? theme.fg("error", clip(firstLine(resultText(result)) || "failed", 40))
				: theme.fg("dim", "written");
			return glanceLine("Write", shortenPath(args.path ?? ""), summary, theme, mode, context?.toolCallId);
		}
		if (context.isError) {
			return expandedBlock(resultText(result) || "error", theme, true, outputCap(mode), mode, toolToggleUrl(context));
		}
		// Expanded: show the written content. The result carries only a byte
		// count — the file text lives in the call args. Mirrors the edit slot's
		// expanded-diff block (cap, child prefix, click-to-collapse).
		const content = typeof args.content === "string" ? args.content.replace(/\n+$/, "") : "";
		if (!content) return resultLine(theme, "Written", false, mode);
		const colored = withMore(content, outputCap(mode) ?? MAX_EXPANDED_WRITE_LINES, theme)
			.split("\n")
			.map((line) => theme.fg("toolOutput", line))
			.join("\n");
		const prefix = childOutputPrefix(mode, theme);
		const contentBlock = new PrefixedText(colored, prefix, mode.kind === "child" ? prefix : GLANCE_INDENT);
		const writeUrl = toolToggleUrl(context);
		return writeUrl ? new ClickToggle(contentBlock, writeUrl) : contentBlock;
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
			const mode = groupMode(context?.toolCallId);
			return treeCall(mode, theme, context, () => callLine(label, argOf(args), theme, "", mode, context));
		},
		renderResult(result: any, { expanded, isPartial }: any, theme: Theme, context: any): Component {
			const args = context.args ?? {};
			const mode = groupMode(context?.toolCallId);
			if (mode.kind === "child" && !mode.headerOpen) {
				// Hidden child: still settle the status for a later re-open.
				if (!isPartial) settleStatus(context, context.isError);
				return new Container();
			}
			const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
			if (isPartial && !expandedNow) {
				if (mode.kind === "child") return new Container();
				return glanceLine(label, argOf(args), theme.fg("dim", "searching…"), theme, mode, context?.toolCallId);
			}
			settleStatus(context, context.isError);
			const text = resultText(result);
			const count = text.split("\n").filter((l: string) => l.trim()).length;
			const unit = count === 1 ? unitSingular : unitPlural;
			if (!expandedNow) {
				const summary = context.isError
					? theme.fg("error", "failed")
					: theme.fg("dim", count > 0 ? `${count} ${unit}` : `no ${unitPlural}`);
				return glanceLine(label, argOf(args), summary, theme, mode, context?.toolCallId);
			}
			if (context.isError) {
				return expandedBlock(text || "error", theme, true, outputCap(mode), mode, toolToggleUrl(context));
			}
			// Expanded: full output. A reached result limit truncates the tool's
			// own output — say so instead of silently showing a cut-off list.
			// Built by hand (not expandedBlock) so the warning keeps its color.
			const limit = result.details?.matchLimitReached ??
				result.details?.resultLimitReached ?? result.details?.entryLimitReached;
			const note = limit ? theme.fg("warning", "(limit reached — results truncated by the tool)") : "";
			const lines = capLines(text.split("\n"), outputCap(mode), theme).map((l) => theme.fg("toolOutput", l));
			if (note) lines.unshift(note);
			const prefix = childOutputPrefix(mode, theme);
			const block = new PrefixedText(lines.join("\n"), prefix, mode.kind === "child" ? prefix : GLANCE_INDENT);
			const url = toolToggleUrl(context);
			return url ? new ClickToggle(block, url) : block;
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
// generic — full custom-ui treatment (grouping, glance lines, status dots,
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
			const mode = groupMode(context?.toolCallId);
			return treeCall(mode, theme, context, () => callLine(label, argOf(args ?? {}), theme, "", mode, context));
		},
		renderResult(result, { expanded, isPartial }, theme, context) {
			const args = context.args ?? {};
			const mode = groupMode(context?.toolCallId);
			if (mode.kind === "child" && !mode.headerOpen) {
				// Hidden child: still settle the status for a later re-open.
				if (!isPartial) settleStatus(context, context.isError);
				return new Container();
			}
			const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
			// Exclude nix-comma's note blocks: they are delivered visually as
			// batch note lines (via the notify routing) and would render twice.
			const text = resultText(result, "[nix-comma]");
			if (isPartial && !context.isError) {
				if (!expandedNow) {
					const live = lastLine(text);
					return glanceLine(label, argOf(args), live ? `Running… ${clip(live, 80)}` : "Running…", theme, mode, context?.toolCallId);
				}
				return liveStream(text, theme, mode, toolToggleUrl(context));
			}
			settleStatus(context, context.isError);
			if (!expandedNow) {
				const lineCount = text.split("\n").filter((l) => l.trim()).length;
				const summary = context.isError
					? theme.fg("error", "failed")
					: theme.fg("dim", lineCount > 0 ? `${lineCount} lines` : "done");
				return glanceLine(label, argOf(args), summary, theme, mode, context?.toolCallId);
			}
			if (context.isError) {
				return expandedBlock(text || "error", theme, true, outputCap(mode), mode, toolToggleUrl(context));
			}
			return expandedBlock(text, theme, false, outputCap(mode), mode, toolToggleUrl(context));
		},
	});
}

// ---------------------------------------------------------------------------
// web tools — pi-web-access's web_search / fetch_content / source_check /
// get_search_content can't adopt the style at registration time (tool-name
// ownership is exclusive and the package doesn't consult the __piCustomUi
// maybeDecorate API), so
// custom-ui.ts prototype-patches ToolExecutionComponent's renderer getters and
// routes those tools here. Same skeleton as genericSlots, but the settled
// summary and the live phase line are derived from the tool's `details`
// (sources/pages/passages counts read better than "N lines"), and the
// expanded view leads with that summary before the full output.
// ---------------------------------------------------------------------------

export type WebToolSpec = {
	label: string;
	argOf: (args: any) => string;
	// Settled summary from result.details; undefined falls back to the first
	// output line (genericSlots behavior).
	summary: (details: any, args: any) => string | undefined;
	// Streaming phase from details.onUpdate updates; undefined falls back to
	// the last streamed output line.
	live?: (details: any) => string | undefined;
};

export function webToolSlots(spec: WebToolSpec): RenderSlots {
	return withToolNotes({
		renderShell: "self",
		renderCall(args, theme, context) {
			const mode = groupMode(context?.toolCallId);
			return treeCall(mode, theme, context, () => callLine(spec.label, spec.argOf(args ?? {}), theme, "", mode, context));
		},
		renderResult(result, { expanded, isPartial }, theme, context) {
			const args = context.args ?? {};
			const details = result?.details ?? {};
			const mode = groupMode(context?.toolCallId);
			if (mode.kind === "child" && !mode.headerOpen) {
				// Hidden child: still settle the status for a later re-open.
				if (!isPartial) settleStatus(context, context.isError);
				return new Container();
			}
			const expandedNow = expanded === true || mode.kind !== "child" || mode.outputOpen;
			const text = resultText(result, "[nix-comma]");
			if (isPartial && !context.isError) {
				if (!expandedNow) {
					const live = (spec.live?.(details) ?? lastLine(text)) || "Running…";
					return glanceLine(spec.label, spec.argOf(args), clip(live, 80), theme, mode, context?.toolCallId);
				}
				// Streamed output wins when there is any; phase-only updates
				// (empty text, details.phase from onUpdate) render the phase line.
				if (text.split("\n").some((l) => l.trim())) return liveStream(text, theme, mode, toolToggleUrl(context));
				const phase = spec.live?.(details);
				return resultLine(theme, clip(phase || "Running…", 80), false, mode);
			}
			settleStatus(context, context.isError);
			const summary = context.isError ? undefined : spec.summary(details, args);
			if (!expandedNow) {
				const line = context.isError
					? theme.fg("error", clip(firstLine(text) || "failed", 56))
					: theme.fg("dim", summary ?? "done");
				return glanceLine(spec.label, spec.argOf(args), line, theme, mode, context?.toolCallId);
			}
			if (context.isError) {
				return expandedBlock(text || "error", theme, true, outputCap(mode), mode, toolToggleUrl(context));
			}
			// Details-driven summary rides the first output line; the full output
			// block follows, capped like every other expanded row.
			const head = summary ?? (firstLine(text) || "done");
			const lines = capLines(text.split("\n"), outputCap(mode), theme);
			const body = [theme.fg("muted", head), ...lines.map((l) => theme.fg("toolOutput", l))].join("\n");
			const prefix = childOutputPrefix(mode, theme);
			const block = new PrefixedText(body, prefix, mode.kind === "child" ? prefix : GLANCE_INDENT);
			// Click-to-collapse, like every other expanded body.
			const url = toolToggleUrl(context);
			return url ? new ClickToggle(block, url) : block;
		},
	});
}
