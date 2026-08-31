// Smoke test: drive the lib's grouping + live header through a simulated
// batch, mimicking what the extensions' event handlers do.
import { trackGroupToolCall, foldToolGroup, collapseToolGroup, groupMode, tickOpenBatch, liveGroupHeaderLine, groupHeaderLine, resetToolGroups, scanToolGroupsFromHistory } from "./lib/custom-ui.ts";

const theme = {
	fg: (c, t) => `\x1b[44m[${c}]\x1b[0m${t}`,
	italic: (t) => `\x1b[3m${t}\x1b[0m`,
	bold: (t) => `\x1b[1m${t}\x1b[0m`,
};

resetToolGroups();
// Batch 0: two tool calls + thinking key 1000
trackGroupToolCall("t1");
trackGroupToolCall("t2", 1000);
if (!tickOpenBatch()) throw new Error("tick should animate a 2-tool batch");
let m = groupMode("t1");
if (m.kind !== "earlier" || !m.header || !m.running) throw new Error(`expected earlier/running header, got ${JSON.stringify(m)}`);
const live1 = liveGroupHeaderLine(theme, m.count, 1234, 0, m.spinner, m.batchIndex);
if (!live1.includes("[accent]")) throw new Error("spinner not accent-colored");
if (!/38;2;\d+;\d+;\d+m/.test(live1)) throw new Error("no truecolor in shimmer");
if (!live1.includes("tool call")) throw new Error("no info segment");

// no palette file in this sandbox → fallback gradient; verify it still colors
console.log("LIVE:", JSON.stringify(live1));

// fold (reasoning streams), tick continues, thought duration visible
foldToolGroup();
m = groupMode("t1");
if (m.kind !== "collapsed" || !m.running) throw new Error("folded batch should be collapsed-kind but running");
console.log("LIVE+THOUGHT:", JSON.stringify(liveGroupHeaderLine(theme, m.count, 2345, 7, m.spinner, m.batchIndex)));

// settle: static header, no truecolor, no spinner
collapseToolGroup();
m = groupMode("t1");
if (m.running) throw new Error("collapsed batch must not be running");
const settled = groupHeaderLine(theme, m.count, 2345);
if (/38;2;/.test(settled)) throw new Error("settled header must be static");
if (!settled.includes("✔")) throw new Error("settled header lost its check glyph");
console.log("SETTLED:", JSON.stringify(settled));

// solo batch: tick keeps running so the in-progress dot animates
resetToolGroups();
trackGroupToolCall("s1");
if (!tickOpenBatch()) throw new Error("solo batch must tick (in-progress dot)");

// verb rotation is deterministic per batch
resetToolGroups();
trackGroupToolCall("a1"); trackGroupToolCall("a2");
collapseToolGroup();
trackGroupToolCall("b1"); trackGroupToolCall("b2");
const mA = groupMode("a1"), mB = groupMode("b1");
if (mA.batchIndex === mB.batchIndex) throw new Error("batchIndex must differ across batches");
console.log("VERBS DIFFER:", mA.batchIndex, "vs", mB.batchIndex);
console.log("OK");

// ── Unification contract (custom-ui ↔ pi-thinking-fold) ──────────
const anim = globalThis.__piCustomUiAnim;
if (!anim) throw new Error("lib must publish __piCustomUiAnim");
if (typeof anim.frame !== "number") throw new Error("anim.frame missing");

// batchOpen tracks the group state machine
resetToolGroups();
if (anim.batchOpen !== false) throw new Error("batchOpen must start false");
resetToolGroups();
trackGroupToolCall("u1");
if (anim.batchOpen !== true) throw new Error("batchOpen must be true with an open batch");
collapseToolGroup();
if (anim.batchOpen !== false) throw new Error("batchOpen must clear on collapse");

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

// Narration exemption (missing-fold fix)
resetToolGroups();
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "assistant", timestamp: 100, content: [{ type: "thinking" }, { type: "toolCall", id: "m1t" }] } },
]);
collapseToolGroup();
let mN = groupMode("m1t");
if (!mN.thoughtKeys || !mN.thoughtKeys.includes(100)) throw new Error("thinking+toolCall must stamp thoughtKey");

resetToolGroups();
scanToolGroupsFromHistory([
	{ type: "message", message: { role: "assistant", timestamp: 200, content: [{ type: "thinking" }, { type: "text", text: "narration" }, { type: "toolCall", id: "m2t" }] } },
]);
collapseToolGroup();
mN = groupMode("m2t");
if (mN.thoughtKeys && mN.thoughtKeys.length) throw new Error("narrated message must NOT stamp thoughtKey");
console.log("OK-NARRATION-EXEMPTION");
