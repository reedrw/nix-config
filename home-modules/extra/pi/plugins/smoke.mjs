// Smoke test: drive the lib's tree state machine + renderers headlessly,
// mimicking what the extensions' event handlers do. Expected-order
// assertions for `├─`/`╰─` placement included (§6 step 1).
import {
	trackGroupToolCall,
	trackThoughtStart,
	closeBatch,
	groupMode,
	tickOpenBatch,
	batchHeaderAnimated,
	liveGroupHeaderLine,
	groupHeaderLine,
	resetToolGroups,
	scanToolGroupsFromHistory,
	toggleBatch,
	toggleTool,
	toggleThought,
	walkTree,
	webToolSlots,
	bash,
	edit,
	resetTurnTokens,
	beginTurnMessage,
	noteTurnDelta,
	noteTurnProviderOutput,
	settleTurnMessage,
	endTurnTokens,
	turnOutputTokens,
	formatTokens,
	installToolExpandWalk,
	handleActionUrl,
	linkWrap,
	wrapTreeText,
	enableLinkActions,
	disableLinkActions,
} from "./lib/custom-ui.ts";
import { getCapabilities, setCapabilities } from "@earendil-works/pi-tui";
import { ToolExecutionComponent } from "@earendil-works/pi-coding-agent";

const theme = {
	fg: (c, t) => `\x1b[44m[${c}]\x1b[0m${t}`,
	italic: (t) => `\x1b[3m${t}\x1b[0m`,
	bold: (t) => `\x1b[1m${t}\x1b[0m`,
};

const tree = globalThis.__piCustomUiTree;
if (!tree) throw new Error("lib must publish __piCustomUiTree");

// ── Tree state machine (live) ────────────────────────────────────
// A running batch auto-opens; its newest child auto-opens with the 16-line
// cap; earlier children render glance rows.
resetToolGroups();
if (batchHeaderAnimated()) throw new Error("no batch → no animated header");
trackGroupToolCall("t1");
if (!batchHeaderAnimated()) throw new Error("running batch → animated header (always)");
let m = groupMode("t1");
if (m.kind !== "child" || !m.first || !m.headerOpen || !m.running || !m.last || m.anchorHosted) {
	throw new Error(`solo running batch mode wrong: ${JSON.stringify(m)}`);
}
if (!m.outputOpen || m.cap !== 16) throw new Error(`newest child must auto-open capped: ${JSON.stringify(m)}`);
if (!tickOpenBatch()) throw new Error("tick should animate a running batch");

trackGroupToolCall("t2");
m = groupMode("t1");
if (m.outputOpen || m.cap !== undefined) throw new Error("earlier child must drop to glance");

if (m.last) throw new Error("earlier child must not be last");
if (m.count !== 2) throw new Error("header count must track batch size");
m = groupMode("t2");
if (!m.outputOpen || m.cap !== 16 || !m.last || m.first) throw new Error(`newest child wrong: ${JSON.stringify(m)}`);

// settle: header goes static-closed, children hidden; user-open persists
closeBatch();
if (batchHeaderAnimated()) throw new Error("settled batch → header static");
if (tickOpenBatch()) throw new Error("settled batch must not tick");
for (const id of ["t1", "t2"]) {
	m = groupMode(id);
	if (m.headerOpen || m.running || m.outputOpen) throw new Error(`settled child must default closed: ${id}`);
}
toggleBatch(0);
m = groupMode("t1");
if (!m.headerOpen || m.running) throw new Error("user toggle must open the settled header");
if (m.outputOpen) throw new Error("settled open header shows glance rows, not output");
toggleBatch(0);
if (groupMode("t1").headerOpen) throw new Error("second toggle must close the header");

// sticky collapse: a user collapse of a RUNNING batch wins over auto-open
trackGroupToolCall("t3");
m = groupMode("t3");
if (!m.headerOpen || !m.outputOpen) throw new Error("new running batch must auto-open");
toggleBatch(1); // user closes the running batch
m = groupMode("t3");
if (m.headerOpen || m.outputOpen) throw new Error("sticky collapse must hide the running batch");
trackGroupToolCall("t4"); // more work joins the sticky-closed batch
if (groupMode("t3").headerOpen || groupMode("t4").headerOpen) throw new Error("sticky must survive new children");
toggleBatch(1); // user re-opens
if (!groupMode("t3").headerOpen || !groupMode("t4").headerOpen) throw new Error("re-open must clear sticky");
closeBatch();

// toggleTool: explicit close of the auto-opened newest child must stick
// (closedTools beats the positional auto-open), explicit open persists.
trackGroupToolCall("k1");
toggleTool("k1");
if (groupMode("k1").outputOpen) throw new Error("explicit close must beat auto-open");
toggleTool("k1");
if (!groupMode("k1").outputOpen || groupMode("k1").cap !== undefined) throw new Error("explicit open must lift the cap");
closeBatch();
if (!groupMode("k1").outputOpen) throw new Error("user-opened child must persist after settle");
toggleTool("k1");
if (groupMode("k1").outputOpen) throw new Error("click must close the child");
resetToolGroups();

// ── Thought branches & anchor (live) ───────────────────────────
// Fresh thinking (no batch) is standalone; when the batch opens it anchors,
// and the run joins as first children in order (§2.3).
resetToolGroups();
trackThoughtStart(1000);
let scope = tree.branchScope(1000);
if (scope.kind !== "standalone" || scope.contentOpen) throw new Error(`fresh think must be standalone: ${JSON.stringify(scope)}`);
trackGroupToolCall("a1"); // the tool call anchors the pending think
scope = tree.branchScope(1000);
if (scope.kind !== "anchor" || !scope.headerOpen || scope.last || !scope.running || scope.count !== 1) {
	throw new Error(`anchored think scope wrong: ${JSON.stringify(scope)}`);
}
m = groupMode("a1");
if (!m.anchorHosted || !m.first) throw new Error("anchor batch: first tool must not host the header");
if (m.kind !== "child" || !m.last) throw new Error("solo tool after anchor think must be last child");

// interleaved thinking mid-batch joins as a later branch (chronological)
trackThoughtStart(1001);
scope = tree.branchScope(1001);
if (scope.kind !== "branch" || scope.headerOpen === false || !scope.last) {
	throw new Error(`mid-batch think must be the last branch: ${JSON.stringify(scope)}`);
}
trackGroupToolCall("a2"); // grows the batch: previous children re-glyph
scope = tree.branchScope(1001);
if (scope.last) throw new Error("previous last child must lose the corner when the batch grows");
scope = tree.branchScope(1000);
if (scope.kind !== "anchor" || scope.last) throw new Error("anchor must stay a non-last child");

// depth-3 thought toggle
toggleThought(1001);
if (!tree.branchScope(1001).contentOpen) throw new Error("thought toggle must open the branch");
toggleThought(1001);
if (tree.branchScope(1001).contentOpen) throw new Error("thought toggle must close the branch");

// header thought total: sum of the batch's branches (durations from the fork)
globalThis.__piCustomUiThoughtFor = new Map([[1000, 30000], [1001, 16500]]);
const anchorHeader = tree.batchHeaderLine(0);
if (!anchorHeader.includes("46s") || anchorHeader.includes("Thought for")) {
	// running header: whole-second live timer, present tense (no "Thought for")
	throw new Error(`anchor header must sum branch durations: ${JSON.stringify(anchorHeader)}`);
}
if (anchorHeader.includes("▸") || !anchorHeader.includes("2 tool calls")) {
	throw new Error("running header must show the live count");
}
closeBatch();
const settledHeader = tree.batchHeaderLine(0);
if (settledHeader.includes("▾") || !settledHeader.includes("▸")) throw new Error("settled closed header must show ▸");
if (!settledHeader.includes("Thought for 46.5s")) throw new Error(`settled header must sum branch durations: ${JSON.stringify(settledHeader)}`);
if (!settledHeader.includes("Ran 2 tool calls")) throw new Error("settled header lost its tool count");
resetToolGroups();

// ── ctrl+o walk: expand/collapse every node ─────────────────────
resetToolGroups();
trackGroupToolCall("c1"); trackGroupToolCall("c2"); trackThoughtStart(2000); trackGroupToolCall("c3");
closeBatch();
walkTree(true);
for (const id of ["c1", "c2", "c3"]) {
	const mm = groupMode(id);
	if (!mm.headerOpen || !mm.outputOpen) throw new Error(`ctrl+o expand must open ${id}`);
}
if (!tree.branchScope(2000).headerOpen || !tree.branchScope(2000).contentOpen) {
	throw new Error("ctrl+o expand must open thinking branches");
}
walkTree(false);
for (const id of ["c1", "c2", "c3"]) {
	const mm = groupMode(id);
	if (mm.headerOpen || mm.outputOpen) throw new Error(`ctrl+o collapse must close ${id}`);
}
if (tree.branchScope(2000).contentOpen) throw new Error("ctrl+o collapse must close thinking");

// ctrl+o via pi's setExpanded (the lib observes the prototype patch)
installToolExpandWalk();
walkFromCtrlOSim: {
	const proto = ToolExecutionComponent.prototype;
	const fake = { expanded: false, updateDisplay() {} };
	proto.setExpanded.call(fake, true);
	if (!groupMode("c1").headerOpen) throw new Error("setExpanded(true) must walk the tree open");
	proto.setExpanded.call(fake, false);
	if (groupMode("c1").headerOpen) throw new Error("setExpanded(false) must walk the tree closed");
}
resetToolGroups();

// pi syncs its (default false) flag onto EVERY new tool component mid-stream —
// those unchanged-flag syncs must NOT close a running batch (the vanished-
// batch bug: children disappeared under a live header after tool #2).
resetToolGroups();
trackGroupToolCall("z1"); trackGroupToolCall("z2");
{
	const proto = ToolExecutionComponent.prototype;
	const fake = { expanded: false, updateDisplay() {} };
	proto.setExpanded.call(fake, false);
	proto.setExpanded.call(fake, false);
	if (!groupMode("z1").headerOpen) throw new Error("unchanged-flag sync must not close the running batch");
	if (!groupMode("z2").outputOpen) throw new Error("unchanged-flag sync must not collapse children");
	proto.setExpanded.call(fake, true);
	if (!groupMode("z1").headerOpen || !groupMode("z1").outputOpen) throw new Error("ctrl+o expand must walk the tree open");
	proto.setExpanded.call(fake, false);
	if (groupMode("z1").headerOpen || groupMode("z1").outputOpen) throw new Error("ctrl+o collapse must walk the tree closed");
}
resetToolGroups();

// ── Scan from history (restore path mirrors the live rules) ─────
// leading run → anchor; interleaved think → branch; user message closes;
// narration breaks the run; narrated messages join the preceding batch.
resetToolGroups();
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "assistant", timestamp: 10, content: [{ type: "thinking", thinking: "a" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 11, content: [{ type: "thinking", thinking: "b" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 12, content: [{ type: "toolCall", id: "r1" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 13, content: [{ type: "thinking", thinking: "c" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 14, content: [{ type: "toolCall", id: "r2" }] } },
	{ type: "message", message: { role: "user", content: "go on" } },
	{ type: "message", message: { role: "assistant", timestamp: 15, content: [{ type: "thinking", thinking: "d" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 16, content: [{ type: "toolCall", id: "r3" }] } },
]);
if (tree.branchScope(10).kind !== "anchor") throw new Error("first leading think must anchor batch 0");
if (tree.branchScope(11).kind !== "branch") throw new Error("second leading think must be a branch");
if (tree.branchScope(11).last) throw new Error("branch 11 must have following siblings");
if (tree.branchScope(13).kind !== "branch") throw new Error("interleaved think must join the batch");
m = groupMode("r1");
if (!m.anchorHosted || !m.first) throw new Error("r1 must be the anchor batch's first tool");
m = groupMode("r2");
if (m.batchIndex !== 0 || !m.last) throw new Error("r2 must close batch 0's child list");
if (tree.branchScope(15).kind !== "anchor" || tree.branchScope(15).batchIndex !== 1) {
	throw new Error("post-user think must anchor the next batch");
}
if (groupMode("r3").batchIndex !== 1) throw new Error("r3 must live in batch 1");

// narration between think and tools breaks the run: the think stays standalone
resetToolGroups();
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "assistant", timestamp: 20, content: [{ type: "thinking", thinking: "x" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 21, content: [{ type: "text", text: "narration" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 22, content: [{ type: "toolCall", id: "n1" }] } },
]);
if (tree.branchScope(20).kind !== "standalone") throw new Error("think before narration must stay standalone");
m = groupMode("n1");
if (m.anchorHosted) throw new Error("bare batch must not claim an anchor");
if (!m.first) throw new Error("bare batch header rides the first tool");

// narrated messages (think → text → toolCall): the thinking streamed under
// the preceding batch → branch there; the text closes it; the tool opens a
// bare batch (no double-count)
resetToolGroups();
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "assistant", timestamp: 30, content: [{ type: "toolCall", id: "q1" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 31, content: [{ type: "thinking", thinking: "hmm" }, { type: "text", text: "narration" }, { type: "toolCall", id: "q2" }] } },
]);
scope = tree.branchScope(31);
if (scope.kind !== "branch" || scope.batchIndex !== 0) throw new Error(`narrated think must join the preceding batch: ${JSON.stringify(scope)}`);
if (scope.headerOpen) throw new Error("settled parent header must be closed");
m = groupMode("q2");
if (m.batchIndex !== 1 || m.anchorHosted) throw new Error("narrated message's tool must open a bare batch");

// solo trees WITH a reasoning block never auto-expand their output — only
// a bare 1-tool tree does
resetToolGroups();
trackThoughtStart(700); trackGroupToolCall("st1");
m = groupMode("st1");
if (m.kind !== "child" || !m.running) throw new Error(`anchor solo mode wrong: ${JSON.stringify(m)}`);
if (m.outputOpen || m.cap !== undefined) throw new Error("1 tool + 1 reasoning must not auto-expand");
resetToolGroups();
trackGroupToolCall("st2");
if (!groupMode("st2").outputOpen) throw new Error("bare 1-tool tree must auto-expand");
resetToolGroups();
console.log("OK-TREE-STATE");

// ── Renderer grammar: glyphs, connectors, header carriers ────────
// strip the mock theme's [color] tags + SGR so literal substrings match
const plainRow = (c) => {
	const r = typeof c?.render === "function" ? c.render(100) : c;
	return (Array.isArray(r) ? r : [r]).join("\n")
		.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
		.replace(/\x1b\]8;;[^\x1b]*\x1b\\/g, "")
		.replace(/\[[a-zA-Z]+\]/g, "");
};
const kctx = (id, extra = {}) => ({ toolCallId: id, state: {}, args: {}, expanded: false, isError: false, isPartial: true, invalidate: () => {}, ...extra });
const stripSgr = (s) => s.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").replace(/\x1b\]8;;[^\x1b]*\x1b\\/g, "");
const callOf = (id) => plainRow(bash.renderCall({ command: "echo hi" }, theme, kctx(id, { args: { command: "echo hi" } })));
const resultOf = (id, text = "out\nout2", extra = {}) =>
	plainRow(bash.renderResult({ content: [{ type: "text", text }] }, { expanded: false, isPartial: false }, theme, kctx(id, { args: { command: "echo hi" }, ...extra })));

// collapsed bare batch: the header IS the row
trackGroupToolCall("g1"); closeBatch();
let row = callOf("g1");
if (!row.includes("▸ Ran 1 tool call") || row.includes("Bash(")) throw new Error(`collapsed header must replace the call line: ${JSON.stringify(row)}`);
if (row.includes("to expand")) throw new Error("settled headers carry no hint suffix");
if (resultOf("g1").length !== 0) throw new Error("hidden child must render nothing");
// open settled: header + glance child, ╰─ corner for the last child
toggleBatch(0);
row = callOf("g1");
if (!row.includes("▾ Ran 1 tool call") || !row.includes("Bash(echo hi)")) throw new Error(`solo open must show the call row: ${JSON.stringify(row)}`);
// solo batch: the header click expands the single tool's output too
row = resultOf("g1");
if (!row.includes("out") || !row.includes("out2")) throw new Error("solo header click must open the inner output");
if (row.includes("├") || row.includes("│")) throw new Error("last child has no connector");
// close the child again: the call row folds away, the glance remains
// (╰─ corner for the last child)
toggleTool("g1");
row = resultOf("g1");
if (!row.includes("╰─ Bash(echo hi)") || !row.includes("2 lines")) throw new Error(`last-child glance needs the corner: ${JSON.stringify(row)}`);
if (row.includes("├") || row.includes("│")) throw new Error("last child has no connector");

// mid-list children: ├─ labels; an expanded mid-list child's output carries
// the through-connector `│` linking its corner past its content
resetToolGroups();
trackGroupToolCall("g1"); trackGroupToolCall("g2");
if (!callOf("g1").includes("2 tool calls")) throw new Error("running header carrier must show the live header");
if (!resultOf("g1").includes(" ├─ Bash(echo hi)")) throw new Error(`mid-list glance needs ├─ under the triangle: ${JSON.stringify(resultOf("g1"))}`);
if (!stripSgr(resultOf("g1")).startsWith(" ├─")) throw new Error("child glyph must sit one column in (triangle alignment)");
toggleTool("g1"); // expand a mid-list child
if (!callOf("g1").includes("├─")) throw new Error("expanded mid-list call row wrong");
row = resultOf("g1");
if (!/│\s+out/.test(row)) throw new Error(`expanded mid-list output needs the through-connector: ${JSON.stringify(row)}`);
if (!groupMode("g2").outputOpen || !groupMode("g2").last) throw new Error("newest running child must be auto-open and last");

// §5: terminal-width wrapping must never break the left rail — long output
// lines and full call arguments wrap at width − prefix, with the connector
// on EVERY continuation (PrefixedText, not Text's full-width wrap).
// (g1 is still mid-list-open from the assertions above.)
const longLine = "x".repeat(300);
const wrapCtx = kctx("g1", { args: { command: longLine } });
const outBlock = bash.renderResult({ content: [{ type: "text", text: longLine }] }, { expanded: false, isPartial: false }, theme, wrapCtx);
const outLines = outBlock.render(40);
if (outLines.length < 2) throw new Error("long output must wrap at narrow widths");
for (const line of outLines) {
	if (!stripSgr(line).startsWith(" │")) throw new Error(`wrapped output lost the rail: ${JSON.stringify(stripSgr(line))}`);
}

const argBlock = bash.renderCall({ command: longLine }, theme, wrapCtx);
const argLines = argBlock.render(40);
// the first child's call slot carries the header line above the call row
const callStart = argLines.findIndex((l) => stripSgr(l).startsWith(" ├─"));
if (callStart === -1) throw new Error("call row missing: " + JSON.stringify(argLines.map(stripSgr)));
for (const line of argLines.slice(callStart + 1)) {
	if (!stripSgr(line).startsWith(" │")) throw new Error(`wrapped arg continuation lost the rail: ${JSON.stringify(stripSgr(line))}`);
}
// multi-line commands (heredoc-style): ONE glyph for the whole call row —
// hard newlines continue with the connector, never a glyph per line
const multi = "cd ~/files/nix-config\necho one\necho two";
const multiBlock = bash.renderCall({ command: multi }, theme, wrapCtx);
const multiLines = multiBlock.render(100).map(stripSgr);
const glyphs = multiLines.filter((l) => /^ [├╰]─/.test(l)).length;
if (glyphs !== 1) throw new Error(`multi-line command must render exactly one glyph, got ${glyphs}: ${JSON.stringify(multiLines)}`);
const glyphIdx = multiLines.findIndex((l) => /^ [├╰]─/.test(l));
for (const line of multiLines.slice(glyphIdx + 1)) {
	if (!line.startsWith(" │")) throw new Error(`multi-line command continuation lost the rail: ${JSON.stringify(line)}`);
}
closeBatch();
resetToolGroups();

// the LAST child's wrapped output keeps the tree's no-rail rule: bare
// space indent under ╰─ (the corner already turned)
resetToolGroups();
trackGroupToolCall("lc1"); closeBatch();
toggleBatch(0); // solo batch: header click opens header + output
const lcCtx = kctx("lc1", { args: { command: longLine } });
const lcBlock = bash.renderResult({ content: [{ type: "text", text: longLine }] }, { expanded: false, isPartial: false }, theme, lcCtx);
const lcLines = lcBlock.render(40).map(stripSgr).filter((l) => l.trim());
if (lcLines.length < 2) throw new Error("last child long output must wrap");
for (const line of lcLines) {
	if (stripSgr(line).includes("│")) throw new Error(`last-child output must not carry the rail: ${JSON.stringify(stripSgr(line))}`);
}
resetToolGroups();

// thinking-anchored batch: the first tool row must NOT host the header
trackThoughtStart(9000);
trackGroupToolCall("g3");
if (callOf("g3").includes("Ran 1 tool call")) throw new Error("anchor batch: header belongs to the think row, not the tool");
if (!callOf("g3").includes("Bash(echo hi)")) throw new Error("anchor batch tool still renders its call row");
closeBatch();
resetToolGroups();

// solo-with-thought running tool: the call row stays visible while
// streaming, and the partial glance must NOT duplicate it
trackThoughtStart(9500);
trackGroupToolCall("g4");
if (!callOf("g4").includes("Bash(echo hi)")) throw new Error("partial tool call row must stay visible (solo-with-thought)");
const partialGlance = plainRow(bash.renderResult({ content: [{ type: "text", text: "out" }] }, { expanded: false, isPartial: true }, theme, kctx("g4", { args: { command: "echo hi" } })));
if (partialGlance.length !== 0) throw new Error(`partial glance must yield to the call row: ${JSON.stringify(partialGlance)}`);
closeBatch();
resetToolGroups();

// ── Unification contract (custom-ui ↔ pi-thinking-fold) ──────────
const anim = globalThis.__piCustomUiAnim;
if (!anim) throw new Error("lib must publish __piCustomUiAnim");
if (typeof anim.frame !== "number") throw new Error("anim.frame missing");

// batchOpen tracks the tree state machine
resetToolGroups();
if (anim.batchOpen !== false) throw new Error("batchOpen must start false");
trackGroupToolCall("u1");
if (anim.batchOpen !== true) throw new Error("batchOpen must be true while a batch runs");
closeBatch();
if (anim.batchOpen !== false) throw new Error("batchOpen must clear on settle");

// batchHeaderAnimated: every running batch shows the live header (its
// spinner owns the one-spinner rule), settled batches none.
resetToolGroups();
trackGroupToolCall("h1"); trackGroupToolCall("h2");
if (!batchHeaderAnimated()) throw new Error("running batch → animated header");
closeBatch();
if (batchHeaderAnimated()) throw new Error("settled batch → static header");

// fork channel helpers: glyphs + connectors in the muted register
if (!tree.thoughtGlyph(true).includes("╰─") || !tree.thoughtGlyph(false).includes("├─")) {
	throw new Error("thought glyphs wrong");
}
if (tree.thoughtConnector(true) !== "    ") throw new Error("last child content must indent 4 spaces");
// child glyphs sit one column in — directly under the header triangle
if (tree.thoughtGlyph(false).startsWith("├")) throw new Error("child glyphs must start at the triangle's column (1 leading space)");
if (!tree.thoughtConnector(false).includes("│")) throw new Error("mid-list child content needs the through-connector");
if (!tree.staticLabel("Thinking… 3s").includes("Thinking… 3s")) throw new Error("static label passthrough broken");

// header URL: the whole header row is one click target
resetToolGroups();
trackGroupToolCall("hu1"); trackGroupToolCall("hu2");
const liveUrl = liveGroupHeaderLine(theme, 2, 1200, 0, 0, 0);
if (liveUrl.includes("to expand")) throw new Error("live header carries no hint suffix");
if (!liveUrl.includes("2 tool calls")) throw new Error("live header lost its info segments");
closeBatch();
resetToolGroups();

// shared clock: wall-clock derived — frame advances with time, not ticks
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const f0 = anim.frame;
sleep(170);
if (anim.frame <= f0) throw new Error("frame must advance with wall clock");

const label = anim.streamingLabel("2s", true, "  (ctrl+t to expand)", 12345);
if (!/38;2;\d+;\d+;\d+m/.test(label)) throw new Error("streamingLabel missing truecolor shimmer");
if (!label.includes("2s")) throw new Error("streamingLabel missing seconds");
if (!label.includes("ctrl+t")) throw new Error("streamingLabel missing expand suffix");
if (!/^\x1b\[38;2;/.test(label)) throw new Error("streamingLabel must open with the accent spinner SGR");
// seconds "0s" path + no-expand path
if (!anim.streamingLabel("0s", false, "  (ctrl+t to expand)", 1).includes("0s")) {
	throw new Error("streamingLabel zero-seconds path broken");
}
// spinner varies with seed across the dots family
const spinnerOf = (s) =>
	anim.streamingLabel("1s", false, "", s).match(/\x1b\[38;2;\d+;\d+;\d+m([^\x1b]*)\x1b\[39m/)[1];
const seen = new Set([spinnerOf(0), spinnerOf(1), spinnerOf(2), spinnerOf(3), spinnerOf(4)]);
if (seen.size < 2) throw new Error("spinner seed variation broken");
// in-progress dot: dotsCircle frames are exactly 2 cells (spaces are
// anti-wiggle padding), accent SGR, animates per frame
const visible = (dot) => dot.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
const dot0 = anim.inProgressDot();
sleep(170);
const dot1 = anim.inProgressDot();
for (const dot of [dot0, dot1]) {
	const v = visible(dot);
	if ([...v].length !== 2) throw new Error(`dot must be exactly 2 cells, got ${JSON.stringify(v)}`);
	if (!/38;2;\d+;\d+;\d+m/.test(dot)) throw new Error("dot missing accent SGR");
	if (!dot.endsWith("\x1b[39m")) throw new Error("dot missing SGR reset");
}
if (dot0 === dot1) throw new Error("in-progress dot must animate with frame");
console.log("ANIM API OK; label:", JSON.stringify(label));
console.log("OK-UNIFICATION");

// ── Live turn token readout ──────────────────────────────────────
// Tracker state machine: settled total + in-flight estimate (max of the
// partial's cumulative provider usage and chars/4 of streamed deltas).
endTurnTokens();
if (turnOutputTokens() !== undefined) throw new Error("tokens must be hidden without an active turn");
resetTurnTokens();
if (turnOutputTokens() !== 0) throw new Error("fresh turn must start at 0");
noteTurnDelta(4000); // est 1000
if (turnOutputTokens() !== 1000) throw new Error(`estimate broken: ${turnOutputTokens()}`);
noteTurnProviderOutput(1200); // provider cumulative beats the estimate
if (turnOutputTokens() !== 1200) throw new Error(`provider mark broken: ${turnOutputTokens()}`);
noteTurnProviderOutput(1100); // stale/lower provider updates never regress
if (turnOutputTokens() !== 1200) throw new Error("provider high-water mark regressed");
noteTurnDelta(2000); // est 1500 now beats the stale provider mark
if (turnOutputTokens() !== 1500) throw new Error(`estimate must take over: ${turnOutputTokens()}`);
beginTurnMessage(); // next message resets per-message accumulation, keeps settled
noteTurnDelta(1600); // est 400
if (turnOutputTokens() !== 400) throw new Error(`beginTurnMessage must reset per-message state: ${turnOutputTokens()}`);
settleTurnMessage(1512); // message_end: provider-reported count lands
if (turnOutputTokens() !== 1512) throw new Error(`settle must land the accurate count: ${turnOutputTokens()}`);
settleTurnMessage(undefined); // aborted message: estimate joins the settled total
if (turnOutputTokens() !== 1512) throw new Error(`empty settle must add 0: ${turnOutputTokens()}`);
if (formatTokens(1512) !== "1.5k" || formatTokens(999) !== "999" || formatTokens(12_345) !== "12k") {
	throw new Error("formatTokens shape broken");
}

// surfaces: live header, streaming label, loader show ↑N while a turn runs
const tokLive = liveGroupHeaderLine(theme, 2, 1234, 0, 0, 0);
if (!tokLive.includes("↑1.5k")) throw new Error("live header missing token readout: " + JSON.stringify(tokLive));
const tokLabel = anim.streamingLabel("2s", true, "  (ctrl+t to expand)", 7);
if (!tokLabel.includes("↑1.5k") || !tokLabel.includes("2s")) throw new Error("streaming label missing token readout");
const tokLoader = anim.loaderLabel(3);
if (!tokLoader.includes("↑1.5k")) throw new Error("loader missing token readout: " + JSON.stringify(tokLoader));

// turn over → readout hidden everywhere
endTurnTokens();
const tokOff = liveGroupHeaderLine(theme, 2, 1234, 0, 0, 0);
if (tokOff.includes("↑")) throw new Error("inactive header must hide the token readout");
if (!anim.streamingLabel("2s", true, "  (ctrl+t to expand)", 7).includes("2s")) {
	throw new Error("streaming label must survive inactive tracker");
}
console.log("OK-TURN-TOKENS");

// ── Web tools (webToolSlots): details-driven summaries ──────────
// Mirrors the specs wired in custom-ui.ts's installWebToolSlots.
const spec = webToolSlots({
	label: "Search",
	argOf: (args) => (Array.isArray(args?.queries) ? `${args.queries.length} queries: ${args.queries[0]}` : (args?.query ?? "")),
	summary: (d) => (typeof d?.totalResults === "number" ? `${d.totalResults} sources` : undefined),
	live: (d) => (d?.phase === "search" ? `Searching "${d.currentQuery}"` : undefined),
});

// glance summary from details (not "N lines") — needs an open header and a
// closed child: two-tool running batch, first child
resetToolGroups();
trackGroupToolCall("w1"); trackGroupToolCall("w1b");
const wg = spec.renderResult(
	{ content: [{ type: "text", text: "answer" }], details: { queryCount: 2, successfulQueries: 2, totalResults: 12 } },
	{ expanded: false, isPartial: false }, theme, kctx("w1", { queries: ["a", "b"] }));
if (!plainRow(wg).includes("12 sources")) throw new Error("webToolSlots glance must use details summary");

// phase-only partial (empty text) falls back to the live phase line — the
// auto-opened newest child streams its phase
const wl = spec.renderResult(
	{ content: [{ type: "text", text: "" }], details: { phase: "search", currentQuery: "solo q" } },
	{ expanded: false, isPartial: true }, theme, kctx("w1b", { query: "solo q" }));
if (!plainRow(wl).includes('Searching "solo q"')) throw new Error("webToolSlots phase fallback broken: " + plainRow(wl));

// expanded leads with the details summary before the output body
toggleTool("w1");
const wx = spec.renderResult(
	{ content: [{ type: "text", text: "body line" }], details: { totalResults: 7 } },
	{ expanded: false, isPartial: false }, theme, kctx("w1", { query: "q" }));
if (!plainRow(wx).includes("7 sources") || !plainRow(wx).includes("body line")) throw new Error("webToolSlots expanded head/body wrong");
closeBatch();

// expanded call line shows the FULL argument (glance rows clip)
resetToolGroups();
trackGroupToolCall("w4"); trackGroupToolCall("w4b");
const longQuery = "x".repeat(200);
const plain = (c) => plainRow(c).replace(/\n+/g, "");
const wClipped = plain(spec.renderResult(
	{ content: [{ type: "text", text: "answer" }], details: {} },
	{ expanded: false, isPartial: false }, theme, kctx("w4", { args: { query: longQuery } })));
if (!wClipped.includes("…") || wClipped.includes(longQuery)) throw new Error("glance must clip long args");
toggleTool("w4");
const wFull = plain(spec.renderCall({ query: longQuery }, theme, kctx("w4", { args: { query: longQuery } }))).replace(/ ?│ {2}/g, "");  // unwrap the continuation prefixes
if (!wFull.includes(longQuery)) throw new Error("expanded call line must show the full arg: " + JSON.stringify(wFull));
closeBatch();
resetToolGroups();

console.log("OK-WEB-TOOLS");

// ── Click plumbing: OSC 8 pi-action links ────────────────────────
// Links are inert until enableLinkActions patches a fullscreen TUI handle.
// before session_start: linkWrap is a no-op, actions still toggle state
if (linkWrap("x", "pi-action://node/tool/1") !== "x") throw new Error("linkWrap must be inert before enableLinkActions");

// settled batch: click the header → children visible; click again → hidden
trackGroupToolCall("k1"); trackGroupToolCall("k2"); closeBatch();
if (!handleActionUrl("pi-action://node/batch/0")) throw new Error("batch URL must dispatch");
if (!groupMode("k1").headerOpen || !groupMode("k2").headerOpen) throw new Error("header click must open depth 2");
if (groupMode("k1").outputOpen) throw new Error("header click must not open depth 3");
handleActionUrl("pi-action://node/batch/0");
if (groupMode("k1").headerOpen) throw new Error("header click must close depth 2 again");
// child toggle: glance row click opens depth 3, explicit close sticks
handleActionUrl("pi-action://node/tool/k1");
if (!groupMode("k1").outputOpen) throw new Error("tool URL must open the child's output");
handleActionUrl("pi-action://node/tool/k1");
if (groupMode("k1").outputOpen) throw new Error("tool URL must close the child's output");
// thought toggle
if (tree.branchScope(4242).contentOpen) throw new Error("thought must start closed");
handleActionUrl("pi-action://node/thought/4242");
if (!tree.branchScope(4242).contentOpen) throw new Error("thought URL must open the branch");
handleActionUrl("pi-action://node/thought/4242");
if (tree.branchScope(4242).contentOpen) throw new Error("thought URL must close the branch");
if (handleActionUrl("https://example.com")) throw new Error("non-action URLs must not dispatch");

// renderers reflect click state: glance row expands to call+output, with links
resetToolGroups();
trackGroupToolCall("c9"); trackGroupToolCall("c9b"); closeBatch();
handleActionUrl("pi-action://node/batch/0");
const collapsedRow = resultOf("c9");
if (!collapsedRow.includes("2 lines") || collapsedRow.includes("out2")) throw new Error("row must glance while collapsed");
handleActionUrl("pi-action://node/tool/c9");
const expandedRow = resultOf("c9");
if (!expandedRow.includes("out2")) throw new Error("click-expanded row must show full output");
handleActionUrl("pi-action://node/tool/c9");
resetToolGroups();

// headers carry OSC 8 targets only when links are enabled
const FAKE = "\x1b]8;;";
const bareHeader = groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0");
if (bareHeader.includes(FAKE)) throw new Error("header must not emit links before enableLinkActions");
const realCaps = getCapabilities();
setCapabilities({ ...realCaps, hyperlinks: true });
const handle = {
	mode: "fullscreen",
	openUrl: (url) => { handle.opened = url; },
	requestRender() { handle.rendered = true; },
};
enableLinkActions(handle);
const linkedHeader = groupHeaderLine(theme, 2, 900, true, "pi-action://node/batch/0");
if (!linkedHeader.includes(FAKE)) throw new Error("header must emit OSC 8 links when enabled");
if (!linkedHeader.includes("pi-action://node/batch/0")) throw new Error("header missing batch link");
if (!linkedHeader.includes("▾")) throw new Error("open header must render the ▾ triangle");
const liveH = liveGroupHeaderLine(theme, 2, 1200, 0, 0, 0, "pi-action://node/batch/0");
if (!liveH.includes(FAKE)) throw new Error("live header must emit the batch link");
// fork-side linkWrap wraps labels with the thought URL
if (!tree.linkWrap("label", "pi-action://node/thought/9").includes(`${FAKE}pi-action://node/thought/9`)) {
	throw new Error("fork linkWrap must wrap the thought URL");
}

// dispatch through the patched openUrl toggles state; other URLs fall through
trackGroupToolCall("h1"); closeBatch();
handle.openUrl("pi-action://node/tool/h1");
if (groupMode("h1").outputOpen !== true) throw Error("patched openUrl must toggle the child");
handle.openUrl("https://example.com");
if (handle.opened !== "https://example.com") throw new Error("non-action URLs must reach the original handler");
disableLinkActions();
setCapabilities(realCaps);
const bareAfter = groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0");
if (bareAfter.includes(FAKE)) throw new Error("disableLinkActions must stop link emission");
resetToolGroups();
console.log("OK-CLICK-ACTIONS");

// ── Header style + diffstat section ─────────────────────────────
// grey bold header (never the old ANSI yellow), one-space indent
const styled = groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0");
if (styled.includes("\x1b[33m")) throw new Error("header must not be yellow");
if (!styled.startsWith(" ") || !styled.includes("\x1b[1m")) throw new Error("header must be bold and indented one space");
// diffstat: its own OSC 8 span (never nested inside the header link), only
// once an Edit settled with changes
enableLinkActions({ mode: "fullscreen", openUrl: () => {}, requestRender() {} });
const statHeader = groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0", { adds: 12, dels: 3 }, "pi-action://node/edits/0");
if (!statHeader.includes("+12") || !statHeader.includes("−3") || !statHeader.includes("pi-action://node/edits/0")) {
	throw new Error(`header diffstat missing: ${JSON.stringify(statHeader)}`);
}
if ((statHeader.match(/\x1b\]8;;/g) ?? []).length !== 4) throw new Error(`diffstat must be a separate link span: ${JSON.stringify(statHeader)}`);
if (!groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0", { adds: 0, dels: 0 }, "pi-action://node/edits/0").includes("+0")) {
	// zero/zero still renders (edits with no net change are legit) — but a
	// batch with NO settled edits must not render the section at all
} else if (groupHeaderLine(theme, 2, 900, false, "pi-action://node/batch/0").includes("edits")) {
	throw new Error("header without diff must omit the diffstat section");
}

// edit registration feeds the header: sum over the batch's edits
resetToolGroups();
trackGroupToolCall("e1"); trackGroupToolCall("e2"); trackGroupToolCall("b1"); closeBatch();
const editKctx = (id, path) => kctx(id, { args: { path } });
edit.renderCall({ path: "a.ts" }, theme, editKctx("e1", "a.ts"));
edit.renderResult({ content: [{ type: "text", text: "ok" }], details: { diff: "+one\n+two\n-old\n" } }, { expanded: false, isPartial: false }, theme, editKctx("e1", "a.ts"));
edit.renderResult({ content: [{ type: "text", text: "ok" }], details: { diff: "+x\n-y\n-z\n" } }, { expanded: false, isPartial: false }, theme, editKctx("e2", "b.ts"));
const statRow = callOf("e1");
if (!statRow.includes("+3") || !statRow.includes("−3")) {
	throw new Error(`bare batch header must carry summed diffstat (+3 −3): ${JSON.stringify(statRow)}`);
}
// diffstat click = batch-wide edit override + opens the header itself
// (one click straight to the changes; bash rows untouched)
if (groupMode("e1").headerOpen) throw new Error("precondition: settled header must start closed");
handleActionUrl("pi-action://node/edits/0");
if (!groupMode("e1").headerOpen) throw new Error("diffstat click must open the header too");
if (!groupMode("e1").outputOpen || groupMode("e1").cap !== undefined) throw new Error("diffstat click must open all edits (uncapped)");
if (!groupMode("e2").outputOpen) throw new Error("diffstat click must open all edits");
if (groupMode("b1").outputOpen) throw new Error("edit override must not touch non-edit rows");
const openEdit = plainRow(edit.renderResult({ content: [{ type: "text", text: "ok" }], details: { diff: "+one\n+two\n-old\n" } }, { expanded: false, isPartial: false }, theme, editKctx("e1", "a.ts")));
if (!openEdit.includes("one") || !openEdit.includes("old")) throw new Error(`overridden edit row must render the diff: ${JSON.stringify(openEdit)}`);
handleActionUrl("pi-action://node/edits/0");
if (groupMode("e1").outputOpen || groupMode("e2").outputOpen) throw new Error("second diffstat click must close all edits");
if (groupMode("e1").headerOpen) throw new Error("second diffstat click must collapse the tree back (header too)");
// a header the user opened themselves survives diff-close
resetToolGroups();
trackGroupToolCall("mo1"); trackGroupToolCall("mo2"); closeBatch();
handleActionUrl("pi-action://node/batch/0"); // user opens the header
edit.renderCall({ path: "a.ts" }, theme, kctx("mo1", { args: { path: "a.ts" } }));
edit.renderResult({ content: [{ type: "text", text: "ok" }], details: { diff: "+a\n" } }, { expanded: false, isPartial: false }, theme, kctx("mo1", { args: { path: "a.ts" } }));
handleActionUrl("pi-action://node/edits/0");
if (!groupMode("mo1").outputOpen) throw new Error("diffstat click must open edits");
handleActionUrl("pi-action://node/edits/0");
if (groupMode("mo1").outputOpen || groupMode("mo2").outputOpen) throw new Error("second diffstat click must close edits");
if (!groupMode("mo1").headerOpen) throw new Error("a manually opened header must survive diff-close");
// per-row toggle dissolves the override — per-row defaults take over
handleActionUrl("pi-action://node/edits/0");
handleActionUrl("pi-action://node/tool/e1");
if (groupMode("e1").outputOpen) throw new Error("per-row close must stick");
if (groupMode("e2").outputOpen) throw new Error("override must dissolve after a per-row toggle");

// solo batch: the header click toggles the single tool's output too
resetToolGroups();
trackGroupToolCall("solo1"); closeBatch();
handleActionUrl("pi-action://node/batch/0");
if (!groupMode("solo1").headerOpen || !groupMode("solo1").outputOpen) throw new Error("solo batch click must expand the inner tool as well");
handleActionUrl("pi-action://node/batch/0");
if (groupMode("solo1").headerOpen || groupMode("solo1").outputOpen) throw new Error("solo batch close must collapse both");

// EXCEPT edits: a solo edit batch's header click must NOT expand the diff —
// only the diffstat click starts edit tools expanded
resetToolGroups();
trackGroupToolCall("se1"); closeBatch();
edit.renderCall({ path: "a.ts" }, theme, kctx("se1", { args: { path: "a.ts" } }));
handleActionUrl("pi-action://node/batch/0");
if (!groupMode("se1").headerOpen) throw new Error("solo edit header click must open the header");
if (groupMode("se1").outputOpen) throw new Error("header click must not expand an edit — only the diffstat does");
handleActionUrl("pi-action://node/edits/0");
if (!groupMode("se1").outputOpen) throw new Error("diffstat click must expand the solo edit");

// a solo batch with a reasoning block is MORE than one node — the header
// click opens the header only, never the tool output
resetToolGroups();
trackGroupToolCall("sn1");
trackThoughtStart(600); // joins the open batch as a branch
closeBatch();
handleActionUrl("pi-action://node/batch/0");
if (!groupMode("sn1").headerOpen) throw new Error("multi-node solo header click must open the header");
if (groupMode("sn1").outputOpen) throw new Error("multi-node solo (tool + reasoning) must not expand on header click");
handleActionUrl("pi-action://node/batch/0");

// expanded content is a click target too: every output line carries the
// node's toggle URL, so clicking the body collapses the node
resetToolGroups();
trackGroupToolCall("ct1"); closeBatch();
handleActionUrl("pi-action://node/batch/0");
const clickBody = bash.renderResult(
	{ content: [{ type: "text", text: "alpha\nbeta" }] },
	{ expanded: true, isPartial: false },
	theme,
	kctx("ct1", { args: { command: "x" } }),
);
const bodyLines = clickBody.render(100);
const clickable = bodyLines.filter((l) => l.includes("pi-action://node/tool/ct1"));
if (clickable.length !== 2) throw new Error(`expanded output lines must carry the toggle URL: ${JSON.stringify(bodyLines)}`);
disableLinkActions();
resetToolGroups();
console.log("OK-HEADER-DIFFSTAT");

console.log("OK-TREE");

// ── Resume repaint: rows that rendered before the grouping rescan ──
//
// Session-switch flows (launch resume, /resume, /fork) render the restored
// transcript BEFORE session_start rescans grouping — those rows render
// untracked (full-width call line, no tree grammar). The rescan must
// re-fire their row invalidators so they repaint through renderCall.
resetToolGroups();
const repaints = [];
const rowCtx = (id) => {
	const ctx = kctx(id);
	let rendered = "";
	const renderRow = () => {
		rendered = plainRow(bash.renderCall({ command: "echo hi" }, theme, ctx));
	};
	ctx.invalidate = () => setTimeout(renderRow, 0);
	renderRow();
	repaints.push(() => rendered);
};
rowCtx("rs1");
rowCtx("rs2");
if (!repaints.every((get) => get().includes("Bash(echo hi)"))) throw new Error("pre-scan sanity: row must render the call");
if (repaints.some((get) => /[├╰]─/.test(get()))) throw new Error("pre-scan rows must render untracked (no glyphs)");
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "user", content: [{ type: "text", text: "go" }] } },
	{ type: "message", message: { role: "assistant", timestamp: 1, content: [{ type: "toolCall", id: "rs1" }, { type: "toolCall", id: "rs2" }] } },
]);
await new Promise((r) => setTimeout(r, 10));
if (!/[├╰]─/.test(repaints[0]()) || !/[├╰]─/.test(repaints[1]())) {
	throw new Error(`rescan must repaint pre-scan rows with tree grammar: ${JSON.stringify([repaints[0](), repaints[1]()])}`);
}
resetToolGroups();

// ── Streaming-args race: pi renders the call row before tool_call tracks it ──
resetToolGroups();
let raceRendered = "";
const raceCtx = kctx("ft1");
const renderRace = () => {
	raceRendered = plainRow(bash.renderCall({ command: "echo hi" }, theme, raceCtx));
};
raceCtx.invalidate = () => setTimeout(renderRace, 0);
renderRace(); // untracked first pass (args streaming)
if (/[├╰]─/.test(raceRendered)) throw new Error("pre-track sanity: row must render untracked");
trackGroupToolCall("ft1");
await new Promise((r) => setTimeout(r, 10));
if (!/[├╰]─/.test(raceRendered)) throw new Error(`tool_call must repaint the row it tracks: ${JSON.stringify(raceRendered)}`);
resetToolGroups();

console.log("OK-RESUME-REPAINT");

// ── Tree wrapping: split-char preference, no stubby heads, link survival ──
setCapabilities({ ...realCaps, hyperlinks: true });
enableLinkActions({ mode: "fullscreen", openUrl: () => {}, requestRender() {} });
{
	const noAnsi = (s) => String(s).replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").replace(/\x1b\]8;;[^\x1b]*\x1b\\/g, "");
	// the exact report: a store path in Bash(...) at the live width
	const path = "d=/nix/store/vkm2y7bxghg40xqly5h1rr9yy3v1qmmc-pi-coding-agent-0.84.2/lib/node_modules/pi-monorepo/dist";
	const cmd = `● Bash(${path}; sed -n '725,760p' $d)`;
	const wrapped = wrapTreeText(cmd, 109);
	const vis = wrapped.map((l) => noAnsi(l).replace(/ +$/, "").length);
	if (vis.some((n) => n > 109)) throw new Error(`tree wrap exceeds the width: ${JSON.stringify(vis)}`);
	if (vis[0] < 100) {
		throw new Error(`first line must fill the width (no stubby dot-only head): ${JSON.stringify(wrapped.map(noAnsi))}`);
	}
	// breaks happen after split characters whenever one exists in the span
	for (let i = 0; i + 1 < wrapped.length; i++) {
		const head = noAnsi(wrapped[i]).replace(/ +$/, "");
		if (!/[-_.,/]$/.test(head)) throw new Error(`line ${i} does not end at a split character: ${JSON.stringify(head.slice(-20))}`);
	}
	// a run with no split characters hard-breaks wherever it must
	const run = "x".repeat(250);
	const hard = wrapTreeText(run, 40);
	if (hard.some((l) => noAnsi(l).length > 40) || noAnsi(hard.join("")).length !== 250) {
		throw new Error("split-less runs must hard-break at the width");
	}
	// the OSC 8 link + SGR state survive every break
	const url = "pi-action://node/tool/xyz";
	const linked = wrapTreeText(linkWrap(`● Bash(${path}; ${"x".repeat(120)})`, url), 60);
	for (let i = 0; i + 1 < linked.length; i++) {
		if (!linked[i + 1].includes(`\x1b]8;;${url}\x1b\\`)) throw new Error(`continuation ${i + 1} lost the link`);
		if (!linked[i].includes("\x1b]8;;\x1b\\")) throw new Error(`line ${i} must close the link before the break`);
	}
	// SGR state re-applies on continuations
	const colored = wrapTreeText("\x1b[31mred ".repeat(40), 30);
	for (let i = 1; i < colored.length; i++) {
		if (!colored[i].startsWith("\x1b[31m")) throw new Error(`continuation ${i} lost its color`);
	}
	// hard newlines force breaks and keep independent wrapping
	const multi = wrapTreeText("aaa\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", 20);
	if (noAnsi(multi[0]) !== "aaa") throw new Error(`hard newlines must force breaks: ${JSON.stringify(multi.map(noAnsi))}`);
	if (multi.slice(1).some((l) => noAnsi(l).length > 20)) throw new Error(`post-newline run must hard-break: ${JSON.stringify(multi.map(noAnsi))}`);
}
console.log("OK-TREE-WRAP");
disableLinkActions();
setCapabilities(realCaps);
