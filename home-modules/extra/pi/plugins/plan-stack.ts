// plan-stack.ts — UI MOCKUP for the "/plan stack + /btw aside agent" plugin.
//
// One plugin, two entrances into the same stack:
//
//   /plan            — YOU view/manipulate the plan (done, off, re-seed)
//   /btw <text>      — off-thread input for the SIDE AGENT. Two outcomes:
//                        question → read-only investigation, answer panel
//                        attaches to the plan queue, plan untouched
//                        work       → same investigation. With a plan
//                        active its one write tool (plan_stack add) exists,
//                        so the fix can be queued at the front; without a
//                        plan /btw is a plain Q&A — never adds steps
//
// ASIDE RESPONSES LIVE IN THE POPUP, not in the transcript and not in the
// widget: the centered overlay IS the aside surface. Chat history keeps a
// one-line breadcrumb when (and only when) the aside adds a step to the
// plan; pure question-asides leave no trace. In the widget, a pushed step
// shows up as a regular ▲ queue row.
//
// /BTW'S DESIGN LANGUAGE: yellow border (base0A — /btw's own color), no
// background band, no prefixes — replies are plain; user follow-ups get a
// yellow rail + base01 band (the custom-ui user-input treatment in /btw
// yellow), with a blank line after each before its reply.
//
// FAKE DATA: the stack lives in module scope and the "side agent" is a 2.4s
// timer — no real plan persistence, no subagent, no system reminders. The
// question/work split is a demo heuristic (see /btw below); the real plugin's
// agent decides by itself, since it holds the plan_stack tool.
//
// Commands (shipped):
//   /btw <text>          the aside agent — see below
// PARKED for now: the /plan stack itself (mock seeding, drafting shimmer,
// ▹ proposed / ▶ running lifecycle). The plan-gated push in /btw is live
// but inert until /plan comes back.
//   /btw <text>          aside agent (TUI: centered popup — chat box for
//                        follow-ups, esc to close, ↑↓/wheel scroll, no
//                        exit button); "…?" (or leading "?") → question path,
//                        leading "!" → force work path, otherwise text
//                        without "?" is treated as work. Non-TUI falls
//                        back to the widget rows below.
//
// Try it: pi -e home-modules/extra/ai/pi/plugins/plan-stack.ts
//
// Widget shape (rail style matches the compact bash/user-message treatment):
//
//   ▎ ⠹ Drafting · side agent · "add a lockfile guard"      ← work, shimmer
//   ▎ ⠹ Aside · side agent · "why does the retry loop…"     ← question, muted
//   ▎ ▹ 1  fix flaky retry test in http/client.ts           ← proposed (ready)
//   ▎ ▹ 2  add backoff jitter unit test
//   ▎ ▹ 3  update CHANGELOG for 2.1
//   ▎ ▹ 3 proposed · /plan go to execute · ◆ goal: ship v2…
//   — after /plan go —
//   ▎ ▶ fix flaky retry test in http/client.ts              ← active
//   ▎ ▲ add lockfile guard to flake update                  ← pushed mid-run
//   ▎   · add backoff jitter unit test
//   ▎ ✔ 5 done · ◆ goal: ship v2 auth refactor
//   ╭─ ◈ aside ─ why does the retry loop thrash under load? ─────────────╮
//   │ The retry loop thrashes because the jitter base is recomputed per │
//   │ attempt instead of per connection — concurrent workers converge    │
//   │ on the same delay and stampede.                                    │
//   │                                                                    │
//   │ The seed lives in http/client.ts:112; upstream Retry-After is fine.│
//   ╰─ 2.4s · 3 read-only calls · ⎿ client.ts, grep, backoff.test.ts ───╯

import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Markdown, Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
	DOTS_SPINNERS,
	base16Bg,
	base16Fg,
	shimmerFrame,
} from "./lib/custom-ui.ts";

const WIDGET_ID = "plan-stack";
const TICK_MS = 80;
const ASIDE_MS = 2400; // fake side-agent latency
const SPINNER = DOTS_SPINNERS[0];
const PANEL_MAX = 88; // aside popup max width
const INPUT_MAX_ROWS = 6; // chat box wraps up to this many rows

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const ITALIC = "\x1b[3m";

// stylix palette via the shared lib (falls back when base16.json is absent)
const RAIL = `${base16Fg("base03", "3e4b59")}▎`;
const BORDER = base16Fg("base03", "3e4b59"); // panel border — muted
const NEXT = base16Fg("base0D", "7aa2f7"); // front of stack — cyan
const PUSH = base16Fg("base0A", "e0af68"); // just-pushed marker — yellow
const DONE = base16Fg("base0B", "9ece6a"); // done counter — green
const GOAL = base16Fg("base0E", "bb9af7"); // long-term goal — purple
const ASIDE = base16Fg("base0C", "7dcfff"); // question path (non-TUI rows) — teal
const ABORDER = base16Fg("base0A", "e0af68"); // /btw identity — yellow
const ERROR = base16Fg("base08", "f7768e"); // failed tool call — red
const USER_BG = base16Bg("base01", "131721"); // user follow-ups band — same
// base01 band user inputs get in the transcript
const MUTED = base16Fg("base04", "565f89");

type Step = { text: string; pushed?: boolean };
// "plan" kind is UNREACHABLE while /plan is parked (only the parked
// command ever constructed it)
type Pending = { kind: "draft" | "aside" | "plan"; text: string };
type Phase = "drafting" | "ready" | "running";

// Aside resolution payload — feeds both the widget panel and the breadcrumb.
type BtwAnswer = {
	question: string;
	answer: string; // markdown digest
	ms: number;
	reads: number; // read-only tool calls the aside agent made
	trail: string[]; // short read-only call summary for the footer
	outcome: "answered" | "pushed";
	step?: string; // outcome === "pushed"
};

let goal = "";
let stack: Step[] = [];
let doneCount = 0;
// PARKED with /plan: phase never leaves "running" while /plan is
// unregistered, so the `phase === "ready"` ▹ branch in widgetLines is
// unreachable. Revive with the /plan command (see plan-stack.md).
let phase: Phase = "running";
let pending: Pending | null = null;
let pendingStart = 0;
let frame = 0;
let tui: { requestRender(): void } | null = null;
let timer: ReturnType<typeof setInterval> | null = null;
let popupBusy = false; // one aside conversation at a time
let currentProc: ChildProcess | null = null; // live aside child, for esc-kill

const clip = (s: string, n: number) =>
	s.length > n ? `${s.slice(0, n - 1)}…` : s;

const stripSgr = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "");
// pi-tui's canonical measure — handles OSC/APC escapes and grapheme widths
// (em-dashes, ▌, ▸ are ambiguous-width; naive .length undercounts them,
// which is what pushed the right border out of the modal)
const visibleLen = (s: string) => visibleWidth(s);

function stopTimer() {
	if (timer) {
		clearInterval(timer);
		timer = null;
	}
}

function widgetLines(width: number): string[] {
	if (!goal && stack.length === 0 && !pending) return [];
	const out: string[] = [];
	const line = (s: string) => out.push(truncateToWidth(s, width));

	// side-agent row. Work gets the shimmer (yellow→orange, push semantics);
	// questions stay quiet: plain spinner, teal "Aside", no shimmer.
	if (pending) {
		const dots = SPINNER[frame % SPINNER.length];
		const quoted = `"${clip(pending.text, 44)}"`;
		if (pending.kind === "plan") {
			// agent drafting the initial stack — cyan sweep (planning, not push)
			const verb = shimmerFrame("Drafting plan", frame);
			line(`${RAIL} ${NEXT}${dots}${RESET} ${verb} ${MUTED}· agent${RESET}`);
		} else if (pending.kind === "draft") {
			const verb = shimmerFrame("Drafting", frame, [
				"base0A",
				"base09",
				"base0D",
			]);
			line(`${RAIL} ${PUSH}${dots}${RESET} ${verb} ${MUTED}· side agent · ${quoted}${RESET}`);
		} else {
			line(`${RAIL} ${ASIDE}${dots}${RESET} ${ITALIC}${ASIDE}Aside${RESET} ${MUTED}· side agent · ${quoted}${RESET}`);
		}
	}

	const [head, ...rest] = stack;
	// UNREACHABLE while /plan is parked (phase never becomes "ready")
	if (head && phase === "ready") {
		// proposed, not yet approved — numbered, muted cyan
		let n = doneCount + 1;
		line(`${RAIL} ${NEXT}▹ ${n++}  ${BOLD}${head.text}${RESET}`);
		for (const s of rest) {
			line(`${RAIL} ${NEXT}▹ ${n++}  ${s.text}${RESET}`);
		}
		line(
			`${RAIL} ${NEXT}▹ ${stack.length} proposed${RESET} ${MUTED}· /plan go to execute${RESET}`,
		);
		line(
			`${RAIL} ${DONE}✔ ${doneCount} done${RESET}${goal ? ` ${MUTED}·${RESET} ${ITALIC}${GOAL}◆ goal: ${goal}${RESET}` : ""}`,
		);
		return ["", ...out];
	}
	if (head) {
		// running: front of stack = what the agent does as soon as it can
		line(`${RAIL} ${BOLD}${NEXT}▶ ${head.text}${RESET}`);
	}
	for (const s of rest) {
		const mark = s.pushed ? `${PUSH}▲${RESET}` : `${MUTED}·${RESET}`;
		line(`${RAIL} ${mark} ${s.text}${RESET}`);
	}
	if (!head && !pending) {
		line(`${RAIL} ${MUTED}(stack empty — agent runs free)${RESET}`);
	}

	line(
		`${RAIL} ${DONE}✔ ${doneCount} done${RESET}${goal ? ` ${MUTED}·${RESET} ${ITALIC}${GOAL}◆ goal: ${goal}${RESET}` : ""}`,
	);

	return ["", ...out]; // leading blank so the stack stands apart
}

// Canned side-agent outputs (mock): initial resolution + follow-up replies.
function fakeCard(kind: "draft" | "aside", text: string, ms: number): BtwAnswer {
	return kind === "draft"
		? {
				question: text,
				answer:
					"Found it: the dialog's save handler races the flag write —\n\n> the flag lands *after* the dialog closes, so the reload reads a stale value.\n\nQueued the fix as a step rather than patching inline (aside agents stay read-only).",
				ms,
				reads: 3,
				trail: ["read http/client.ts (lines 90–140)", "grep 'Retry-After' src/http/", "read http/backoff.test.ts"],
				outcome: "pushed",
				step: text,
			}
		: {
				question: text,
				answer:
					"The retry loop thrashes because the jitter base is recomputed **per attempt** instead of per connection — concurrent workers converge on the same delay and stampede.\n\nThe seed lives in `http/client.ts:112`; upstream `Retry-After` handling is fine.\n\nDetails:\n\n- `computeBackoff(attempt)` samples jitter from `[0, base]` where `base` resets per attempt\n- workers that fail together re-sample into the same narrow window\n- the server sees synchronized retry bursts every ~400ms\n- `base` should persist across attempts for the life of the connection\n- the unit test asserts a spread, not a point value — that's why it flakes\n- fix belongs in `http/client.ts`, one-line change plus test update",
				ms,
				reads: 3,
				trail: ["read http/client.ts (lines 90–140)", "grep 'Retry-After' src/http/", "read http/backoff.test.ts"],
				outcome: "answered",
			};
}

function fakeReply(q: string): string {
	return `Short answer: yes — the same reasoning applies to the reload path. (mock reply to "${clip(q, 36)}")`;
}

function startPending(p: Pending, pi: ExtensionAPI, ctx: any) {
	if (pending || timer) {
		ctx.ui.notify("Side agent already busy — hold on", "warning");
		return;
	}
	pending = p;
	pendingStart = Date.now();
	frame = 0;
	timer = setInterval(() => {
		frame++;
		if (Date.now() - pendingStart >= ASIDE_MS) {
			stopTimer();
			const text = pending!.text;
			if (pending!.kind === "plan") {
				// agent proposed the initial stack — mockup seeds it directly
				pending = null;
				stack = [
					{ text: "fix flaky retry test in http/client.ts" },
					{ text: "add backoff jitter unit test" },
					{ text: "update CHANGELOG for 2.1" },
				];
				doneCount = 0;
				phase = "ready";
				ctx.ui.notify("Plan drafted — /plan go to start, or refine in chat", "info");
			} else {
			const card = fakeCard(
				pending!.kind === "draft" ? "draft" : "aside",
				text,
				Date.now() - pendingStart,
			);
			pending = null;
			if (card.outcome === "pushed" && goal) {
				// /btw NEVER adds steps on its own: the plan tool exists only
				// while a plan is active. Without one, /btw is a plain Q&A.
				stack.unshift({ text: card.step!, pushed: true });
				// breadcrumbs record plan mutations only — question-asides are
				// ephemeral UI and leave no transcript trace
				pi.appendEntry("btw-note", { card });
			}
			}
		}
		tui?.requestRender();
	}, TICK_MS);
	timer.unref?.();
	tui?.requestRender();
}

// ── Aside side agent ────────────────────────────────────────────────
// Real implementation: each aside turn spawns a one-shot `pi --mode json`
// child (read-only tools) and parses its NDJSON event stream. The child's
// plan tool is a bridge extension (registered only while a plan is active)
// that appends JSON lines to a bridge file this extension polls.

// Child-side bridge extension: registers plan_add_step, which appends to
// the bridge file. Spawned via -e; the bridge path travels in an env var.
const BRIDGE_EXT = `import { appendFileSync } from "node:fs";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "plan_add_step",
    label: "Plan: Add Step",
    description:
      "Add a step to the FRONT of the active plan queue. Use this when your answer implies work that belongs in the plan, instead of doing the work yourself. The step must be a short imperative description.",
    parameters: Type.Object({
      step: Type.String({ description: "Concise imperative step description" }),
    }),
    async execute(_id, params) {
      try {
        appendFileSync(
          process.env.PI_PLAN_BRIDGE_FILE ?? "",
          JSON.stringify({ step: String(params.step) }) + "\\n",
        );
        return { content: [{ type: "text", text: "Queued at the front of the plan." }] };
      } catch (e) {
        return { content: [{ type: "text", text: \`Failed to queue: \${e}\` }] };
      }
    },
  });
}
`;

// One-cell arg preview for a glance row, by tool
function argSummary(tool: string, args: any): string {
	const a = args ?? {};
	if (a.step) return String(a.step);
	if (a.pattern) return `${a.pattern}${a.path ? ` ${a.path}` : ""}`;
	if (a.path) return String(a.path);
	if (a.command) return String(a.command);
	try {
		return clip(JSON.stringify(a), 40);
	} catch {
		return "";
	}
}

// Trimmed main-conversation transcript, inlined into the aside agent's
// system prompt: user/assistant text, the main agent's THINKING, its tool
// calls, and tool results — so the aside agent can explain the main
// agent's reasoning and activity without interrupting it. Newest-heavy:
// per-item clips, drops oldest lines when over budget.
function mainContextBlock(ctx: any): string {
	try {
		const entries = ctx.sessionManager?.getBranch?.() ?? [];
		const items: { kind: "user" | "thinking" | "tool" | "result" | "text"; text: string }[] = [];
		for (const e of entries) {
			if (e.type !== "message") continue;
			const m = e.message;
			if (!m) continue;
			const parts = Array.isArray(m.content) ? m.content : [];
			if (m.role === "user") {
				const text = (typeof m.content === "string" ? m.content : parts
					.filter((c: any) => c.type === "text")
					.map((c: any) => c.text)
					.join(" ")).trim();
				if (text) items.push({ kind: "user", text });
			} else if (m.role === "assistant") {
				// thinking, tool calls, and text — in order, so the aside agent
				// can explain the main agent's reasoning, not just its output
				for (const c of parts) {
					if (c.type === "thinking" && c.thinking?.trim())
						items.push({ kind: "thinking", text: c.thinking.trim() });
					else if (c.type === "toolCall") {
						const name = c.name ?? "tool";
						items.push({ kind: "tool", text: `${name}(${argSummary(name, c.arguments)})` });
					} else if (c.type === "text" && c.text?.trim()) {
						items.push({ kind: "text", text: c.text.trim() });
					}
				}
			} else if (m.role === "toolResult") {
				const text = parts
					.filter((c: any) => c.type === "text")
					.map((c: any) => c.text)
					.join(" ")
					.trim();
				const first = text.split("\n").find((l: string) => l.trim()) ?? "";
				if (first) items.push({ kind: "result", text: first });
			}
		}
		if (!items.length) return "";

		// age-tiered clip budgets. Recent items get generous room; old ones
		// decay to one-line stubs; ancient thinking/results vanish entirely
		// (a 40-message-old result's first line has near-zero value, but a
		// tool CALL's args stay — `Read(src/server.ts)` is dense signal).
		const TIERS = [
			{ until: 12, user: 400, thinking: 500, tool: 120, result: 120, text: 400 },
			{ until: 30, user: 200, thinking: 150, tool: 80, result: 60, text: 200 },
			{ until: Infinity, user: 120, thinking: 0, tool: 60, result: 0, text: 120 },
		];
		const n = items.length;
		const lines: string[] = [];
		items.forEach((it, i) => {
			const age = n - 1 - i;
			const t = TIERS.find((x) => age < x.until)!;
			const w = it.text;
			switch (it.kind) {
				case "user":
					lines.push(`user: ${clip(w, t.user)}`);
					break;
				case "thinking":
					if (t.thinking > 0) lines.push(`assistant (thinking): ${clip(w, t.thinking)}`);
					break;
				case "tool":
					lines.push(`assistant (tool): ${clip(w, t.tool)}`);
					break;
				case "result":
					if (t.result > 0) lines.push(`toolResult: ${clip(w, t.result)}`);
					break;
				case "text":
					lines.push(`assistant: ${clip(w, t.text)}`);
					break;
			}
		});

		// whole-line char budget: drop oldest lines until under cap
		const cap = 8000;
		let block = lines.join("\n");
		let drop = 0;
		while (block.length > cap && drop < lines.length - 1) {
			drop++;
			block = lines.slice(drop).join("\n");
		}
		if (drop > 0) block = `… ${drop} earlier items omitted\n${block}`;
		return `## Recent main-conversation context\nYou are aside of an ongoing conversation. This includes the main agent's reasoning and tool activity — use it to explain its behavior or resolve references like "the thing you just changed".\n\n${block}`;
	} catch {
		return "";
	}
}

// One-cell result summary for a completed glance row
function resultSummary(result: any, isError: boolean): string {
	if (isError) return "error";
	const text = Array.isArray(result?.content)
		? result.content.map((c: any) => c.text ?? "").join("\n")
		: typeof result === "string"
			? result
			: "";
	const lines = text.split("\n").filter((l: string) => l.trim());
	return lines.length ? `${lines.length} line${lines.length === 1 ? "" : "s"}` : "done";
}

// ── Aside popup: centered overlay conversation ──────────────────────
// ctx.ui.custom({ overlay: true }): the popup owns input while open — the
// chat box is focused by default, ↑↓/wheel scroll the transcript, tab moves
// focus to the Exit row (enter activates), escape closes. The main agent keeps running behind it but can't be
// steered mid-conversation (that's a feature: no accidental derailment).
// The fake side agent resolves after ASIDE_MS; follow-ups in the chat box
// each get a canned reply. A pushed step lands in the stack the moment the
// digest arrives, so the widget behind the popup is already up to date.

type PopupLine = {
	who: "aside" | "you" | "sys" | "tool" | "md";
	text?: string;
	label?: string;
	arg?: string;
	summary?: string;
	error?: boolean;
};

async function openAsidePopup(
	kind: "draft" | "aside",
	question: string,
	pi: ExtensionAPI,
	ctx: any,
) {
	if (popupBusy || pending || timer) {
		ctx.ui.notify("Side agent already busy — hold on", "warning");
		return;
	}
	popupBusy = true;
	const cwd: string = ctx.cwd ?? process.cwd();

	// bridge: temp dir holds the child-side plan tool extension, the bridge
	// JSONL file it appends to, and the per-turn system prompt
	const tmpDir = mkdtempSync(join(tmpdir(), "pi-aside-"));
	const bridgePath = join(tmpDir, "bridge.jsonl");
	const sysPath = join(tmpDir, "system-prompt.md");
	const bridgeExtPath = join(tmpDir, "plan-bridge.ts");
	writeFileSync(bridgeExtPath, BRIDGE_EXT);
	let bridgeOffset = 0;
	const cleanup = () => {
		try {
			rmSync(tmpDir, { recursive: true, force: true });
		} catch {}
	};

	await ctx.ui.custom(
		(tui2: any, _theme: any, _kb: any, done: (v: boolean) => void) => {
			let busy = true; // a child run is in flight
			let everReplied = false;
			let liveCall: { label: string; arg: string } | null = null;
			const liveById = new Map<string, { label: string; arg: string }>();
			let callCount = 0;
			let replyBuf = "";
			let turnQ = question;
			const history: { q: string; a: string }[] = [];
			const lines: PopupLine[] = [];
			let value = "";
			let scroll = 0;
			let lastBodyLen = 0;
			let frame = 0;
			const mdCacheMap = new Map<string, Markdown>();
			// custom-ui user-input treatment, but with /btw's yellow rail:
			// yellow bar + base01 band. NOTE: no RESET inside the banded
			// segment — a mid-row RESET would kill the band after the rail
			const userRail = `${ABORDER}▎`;

			const stop = () => {
				if (timer) {
					clearInterval(timer);
					timer = null;
				}
			};

			// plan bridge: the child's plan_add_step appends JSON lines; apply
			// them to the stack here (plan-active gated — the tool isn't even
			// registered in the child without an active plan, this is belt and braces)
			const pollBridge = () => {
				if (!bridgePath || !existsSync(bridgePath)) return;
				let data = "";
				try {
					data = readFileSync(bridgePath, "utf8").slice(bridgeOffset);
				} catch {
					return;
				}
				if (!data) return;
				bridgeOffset += data.length;
				for (const line of data.split("\n")) {
					const t = line.trim();
					if (!t) continue;
					try {
						const { step } = JSON.parse(t);
						if (goal) {
							stack.unshift({ text: String(step), pushed: true });
							lines.push({ who: "sys", text: `queued at front of plan: ${step}` });
							pi.appendEntry("btw-note", {
								card: {
									question,
									answer: String(step),
									ms: 0,
									reads: 0,
									trail: [],
									outcome: "pushed",
									step: String(step),
								},
							});
						}
					} catch {}
				}
			};

			// one-shot child per aside turn; follow-ups re-spawn with history
			// primed into the prompt
			const runTurn = (q: string) => {
				busy = true;
				turnQ = q;
				replyBuf = "";
				const tools = ["read", "grep", "find", "ls"];
				const sys = [
					"You are the aside agent: answering a quick off-thread question about this repository.",
					"Strictly read-only. Answer concisely — your reply is read in a small popup while the main agent keeps working.",
				];
				if (goal) {
					tools.push("plan_add_step");
					sys.push(`A plan is active. Goal: ${goal}. Next step: ${stack[0]?.text ?? "(none)"}.`);
					sys.push(
						"If your answer implies work that belongs in the plan, enqueue it with the plan_add_step tool (short imperative step) instead of doing the work yourself.",
					);
				}
				// main-chat context: recomputed every turn, so follow-ups see
				// fresh main-agent state
				const mainCtx = mainContextBlock(ctx);
				if (mainCtx) sys.push(mainCtx);
				writeFileSync(sysPath, sys.join("\n"));
				let prompt = q;
				if (history.length) {
					prompt =
						history
							.slice(-3)
							.map((h) => `Earlier question: ${h.q}\nYour answer: ${h.a}`)
							.join("\n\n") + `\n\nNew question: ${q}`;
				}
				const args = [
					"--mode",
					"json",
					"-p",
					"--no-session",
					"-e",
					bridgeExtPath,
					"--tools",
					tools.join(","),
					"--append-system-prompt",
					sysPath,
					prompt,
				];
				let child: ChildProcess;
				try {
					child = spawn("pi", args, {
						cwd,
						env: { ...process.env, PI_PLAN_BRIDGE_FILE: bridgePath },
						stdio: ["ignore", "pipe", "pipe"],
					});
				} catch (e) {
					lines.push({ who: "sys", text: `aside agent failed to spawn: ${e}` });
					busy = false;
					return;
				}
				currentProc = child;
				let buf = "";
				const finish = () => {
					if (currentProc === child) currentProc = null;
					if (!busy) return;
					busy = false;
					if (liveCall) {
						lines.push({ who: "tool", label: liveCall.label, arg: liveCall.arg, summary: "done" });
						liveCall = null;
					}
					if (replyBuf.trim()) {
						lines.push({ who: "md", text: replyBuf.trim() });
						history.push({ q: turnQ, a: replyBuf.trim() });
						everReplied = true;
					} else {
						lines.push({ who: "sys", text: "aside agent returned no answer" });
					}
					replyBuf = "";
					tui2.requestRender();
				};
				child.stdout?.on("data", (d: Buffer) => {
					buf += d.toString();
					const parts = buf.split("\n");
					buf = parts.pop() ?? "";
					for (const line of parts) {
						if (!line.trim()) continue;
						let ev: any;
						try {
							ev = JSON.parse(line);
						} catch {
							continue;
						}
						if (ev.type === "tool_execution_start") {
							const call = { label: ev.toolName, arg: argSummary(ev.toolName, ev.args) };
							liveById.set(ev.toolCallId, call);
							liveCall = call;
						} else if (ev.type === "tool_execution_end") {
							const call = liveById.get(ev.toolCallId);
							liveById.delete(ev.toolCallId);
							lines.push({
								who: "tool",
								label: ev.toolName,
								arg: call?.arg ?? argSummary(ev.toolName, ev.args),
								summary: resultSummary(ev.result, !!ev.isError),
								error: !!ev.isError,
							});
							if (liveCall && liveCall.arg === (call?.arg ?? "")) liveCall = null;
							liveCall = null;
							callCount++;
						} else if (ev.type === "message_end" && ev.message?.role === "assistant") {
							const text = (ev.message.content ?? [])
								.filter((c: any) => c.type === "text")
								.map((c: any) => c.text)
								.join("");
							if (text.trim()) replyBuf = text;
						} else if (ev.type === "agent_end") {
							finish();
						}
					}
				});
				child.stderr?.on("data", () => {});
				child.on("error", (e) => {
					lines.push({ who: "sys", text: `aside agent failed: ${e}` });
					busy = false;
					tui2.requestRender();
				});
				child.on("close", () => finish());
			};

			timer = setInterval(() => {
				frame++;
				pollBridge();
				tui2.requestRender();
			}, TICK_MS);
			timer.unref?.();
			runTurn(question);

			return {
				handleInput(data: string) {
					if (data === "\x1b[B" || data.startsWith("\x1b[<65")) {
						// ↓ / wheel down: scroll toward the latest
						scroll = Math.max(0, scroll - (data === "\x1b[B" ? 2 : 3));
						tui2.requestRender();
						return;
					}
					if (data === "\x1b[A" || data.startsWith("\x1b[<64")) {
						// ↑ / wheel up: scroll toward older lines
						scroll = Math.min(
							scroll + (data === "\x1b[A" ? 2 : 3),
							Math.max(0, lastBodyLen - 16),
						);
						tui2.requestRender();
						return;
					}
					if (data === "\x1b") {
						stop();
						currentProc?.kill("SIGTERM");
						cleanup();
						done(false);
						return;
					}
					if (data === "\r" || data === "\n") {
						const v = value.trim();
						if (v && !busy) {
							lines.push({ who: "you", text: v });
							lines.push({ t: "", who: "you" } as any);
							value = "";
							runTurn(v);
						}
						value = "";
						tui2.requestRender();
						return;
					}
					if (data === "\x7f") {
						value = value.slice(0, -1);
						tui2.requestRender();
						return;
					}
					if (!data.startsWith("\x1b") && !/[\x00-\x1f\x7f]/.test(data)) {
						value += data;
						tui2.requestRender();
					}
				},
				render(width: number) {
					const ww = Math.min(width - 4, PANEL_MAX);
					const inner = ww - 4;
					const out: string[] = [];

					// top rule (yellow = /btw's own color)
					const headPrefix = `─ ${ABORDER}◈${RESET} ${ITALIC}${ABORDER}aside${RESET} ${ABORDER}─ `;
					const head = `${headPrefix}${clip(question, Math.max(3, ww - 5 - visibleLen(headPrefix)))} `;
					out.push(`${ABORDER}╭${head}${ABORDER}${"─".repeat(Math.max(1, ww - 2 - visibleLen(head)))}╮${RESET}`);

					// body: investigation spinner / digest / conversation
					const body: { t: string; band?: boolean }[] = [];
					if (busy && !everReplied) {
						const dots = SPINNER[frame % SPINNER.length];
						body.push({ t: `${ABORDER}${dots}${RESET} ${MUTED}Investigating · side agent · ${callCount} call${callCount === 1 ? "" : "s"}${RESET}` });
					}
					for (const ln of lines) {
						// blank lines bracket the user message
						if (ln.who === "you" && body.length > 0 && body[body.length - 1].t !== "")
							body.push({ t: "" });
						if (ln.who === "tool") {
							// completed call: status-colored dot, capitalized tool
							const dot = ln.error ? `${ERROR}●${RESET}` : `${ABORDER}●${RESET}`;
							const name = (ln.label ?? "tool").charAt(0).toUpperCase() + (ln.label ?? "tool").slice(1);
							const rest = ln.summary ? `${MUTED}· ${ln.summary}${RESET}` : "";
							body.push({ t: `${dot} ${name}(${clip(ln.arg ?? "", inner - 6)}) ${rest}` });
						}
						else if (ln.who === "sys") body.push({ t: `${PUSH}◆ ${clip(ln.text ?? "", inner - 2)}${RESET}` });
						else if (ln.who === "md") {
							let m = mdCacheMap.get(ln.text ?? "");
							if (!m) {
								m = new Markdown(ln.text ?? "", 0, 0, getMarkdownTheme());
								mdCacheMap.set(ln.text ?? "", m);
							}
							for (const l of m.render(inner)) {
								body.push({ t: stripSgr(l).trim() ? truncateToWidth(l.trimEnd(), inner) : "" });
							}
						}
						else if (ln.who === "you") {
							body.push({ t: clip(ln.text ?? "", inner - 3), band: true });
							body.push({ t: "" });
						}
						else body.push({ t: clip(ln.text ?? "", inner) });
					}
					if (liveCall) {
						const dots = SPINNER[frame % SPINNER.length];
						const name = liveCall.label.charAt(0).toUpperCase() + liveCall.label.slice(1);
						body.push({ t: `${ABORDER}${dots}${RESET} ${MUTED}${name}(${clip(liveCall.arg, inner - 8)})${RESET}` });
					}
					if (busy && everReplied) {
						const dots = SPINNER[frame % SPINNER.length];
						body.push({ t: `${ABORDER}${dots}${RESET} ${MUTED}aside is thinking…${RESET}` });
					}
					const max = 16;
					scroll = Math.max(0, Math.min(scroll, Math.max(0, body.length - max)));
					const viewStart = Math.max(0, body.length - max - scroll);
					const view = body.slice(viewStart, body.length - scroll);
					const above = viewStart;
					if (above > 0) view.unshift({ t: `${MUTED}… ${above} more above · ↑${RESET}` });
					if (scroll > 0) view.push({ t: `${MUTED}… ${scroll} more below · ↓${RESET}` });
					for (const it of view) {
						if (it.band) {
							// custom-ui user-input style: accent rail + base01 band.
							// the rail is a known 1-cell glyph — don't run it through
							// the measurer (block elements are ambiguous-width)
							const pad = " ".repeat(Math.max(0, inner - 2 - visibleLen(it.t)));
							out.push(`${ABORDER}│${RESET}${USER_BG} ${userRail} ${it.t}${pad} ${RESET}${ABORDER}│${RESET}`);
						} else {
							const pad = " ".repeat(Math.max(0, inner - visibleLen(it.t)));
							out.push(`${ABORDER}│${RESET} ${it.t}${pad} ${ABORDER}│${RESET}`);
						}
					}

					// chat box — framed by full-width rules like pi's default
					// input box; escape is the one true way to exit. Long input
					// wraps across up to INPUT_MAX_ROWS rows (tail visible, so the
					// cursor is always on screen); short input stays one row.
					const rule = `${BORDER}${"─".repeat(Math.max(1, inner + 2))}${RESET}`;
					out.push(`${ABORDER}│${RESET}${rule}${ABORDER}│${RESET}`);
					const inW = Math.max(1, inner - 2); // wrap width (2 cells spare)
					const inRows: string[] = [];
					let cur = "";
					const place = (word: string) => {
						if (!cur) { cur = word; return; }
						if (visibleLen(cur) + 1 + visibleLen(word) <= inW) cur += ` ${word}`;
						else { inRows.push(cur); cur = word; }
					};
					for (const word of value.split(" ")) {
						if (!word) continue;
						if (visibleLen(word) <= inW) { place(word); continue; }
						// token longer than a row: hard-break at the char level
						let rest = word;
						while (visibleLen(rest) > inW) {
							if (cur) { inRows.push(cur); cur = ""; }
							let chunk = "";
							let w = 0;
							for (const ch of rest) {
								const cw = visibleWidth(ch);
								if (w + cw > inW) break;
								chunk += ch;
								w += cw;
							}
							inRows.push(chunk);
							rest = rest.slice(chunk.length);
						}
						place(rest);
					}
					inRows.push(cur);
					const shownRows = inRows.slice(-INPUT_MAX_ROWS);
					shownRows.forEach((r, i) => {
						const first = i === 0 && inRows.length > INPUT_MAX_ROWS;
						const lead = first ? `${MUTED}…${RESET} ` : "  ";
						const isLast = i === shownRows.length - 1;
						const content = `${lead}${r}${isLast ? "▌" : ""}`;
						const pad = " ".repeat(Math.max(0, inner - visibleLen(content)));
						out.push(`${ABORDER}│${RESET} ${content}${pad} ${ABORDER}│${RESET}`);
					});
					out.push(`${ABORDER}│${RESET}${rule}${ABORDER}│${RESET}`);

					// bottom hint
					const foot = `─ ${MUTED}enter send · ↑↓/wheel scroll · esc close${RESET} `;
					out.push(`${ABORDER}╰${foot}${ABORDER}${"─".repeat(Math.max(1, ww - 2 - visibleLen(foot)))}╯${RESET}`);
					lastBodyLen = body.length;
					return out;
				},
				invalidate() {},
			};
		},
		{
			overlay: true,
			overlayOptions: { anchor: "center", width: "66%" },
			onHandle: (h: any) => h.focus(),
		},
	);
	popupBusy = false;
	cleanup();
	tui?.requestRender();
}
export default function planStackMockup(pi: ExtensionAPI) {
	// Breadcrumb for the session record: one dim line, no content. The full
	// digest lives in the widget panel while it's relevant; this survives in
	// history so an aside is never invisible after the fact. Registered at
	// load time so restored sessions re-render it.
	pi.registerEntryRenderer("btw-note", (entry) => {
		const card = (entry.data as { card: BtwAnswer }).card;
		const icon =
			card.outcome === "pushed" ? `${PUSH}◆${RESET}` : `${ASIDE}◈${RESET}`;
		const what =
			card.outcome === "pushed" ? "aside → step" : "aside answered";
		return new Text(
			`  ${icon} ${MUTED}${what} · ${clip(card.question, 64)}${RESET}`,
			0,
			0,
		);
	});

	// The aside-agent entrance. Demo heuristic: leading "?" forces the
	// question path, leading "!" forces work, otherwise a "?" anywhere means
	// question. The real plugin has no heuristic — the agent holds
	// plan_stack and decides whether the answer needs to become a step.
	pi.registerCommand("btw", {
		description: "Plan stack mockup: /btw <question | aside work>",
		handler: async (args, ctx) => {
			const trimmed =
				args.trim() || "why does the retry loop thrash under load?";
			const forced = /^[?!]/.test(trimmed);
			const text = trimmed.replace(/^[?!]\s*/, "");
			const kind: Pending["kind"] = forced
				? trimmed.startsWith("!")
					? "draft"
					: "aside"
				: /\?/.test(trimmed)
					? "aside"
					: "draft";
			// NOTE: no ensureSeeded() — /btw works without a plan; a pushed
			// step on an empty stack simply becomes the ▶ current step
			if (ctx.mode === "tui") {
				await openAsidePopup(kind, text, pi, ctx);
			} else {
				// non-TUI fallback: widget rows instead of the popup
				startPending({ kind, text }, pi, ctx);
			}
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setWidget(WIDGET_ID, (t) => {
			tui = t;
			return {
				render: (width: number) => widgetLines(width),
				invalidate() {},
				dispose() {
					tui = null;
				},
			};
		});
	});

	pi.on("session_shutdown", async () => {
		stopTimer();
		tui = null;
	});
}
