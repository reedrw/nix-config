// Pi statusline — port of the Claude Code statusline.
// Shows the model, thinking level (effort), a context-usage meter, session
// spend, a prompt-cache hit rate, and the git repo + branch. Toggle with
// /statusbar; auto-enables
// in TUI sessions. (The Claude 5h/7d rate-limit meters have no pi equivalent
// and are replaced by the spend indicator.)
//
// Clicking the model chip (or the routing info line) expands an OpenRouter
// routing line: the upstream provider actually serving requests this
// session, with its quantization/uptime/throughput/billed cost. That line
// also carries a "(change provider)" click target into the provider-pin
// dialog, which lives in pin-provider.ts + lib/openrouter.ts — including
// the pin state and the request injection that enforces it.
//
// While the agent is working (between agent_start and agent_settled) the
// effort label animates: the level's color pulses through grey text, and
// "maximum" gets a rolling rainbow. A live tok/s meter (rolling 3s window
// over output tokens) and turn timer sit between the ctx bar and spend
// meter while streaming; once the turn settles they freeze into a dimmed
// summary of the last turn. A session-wide prompt-cache hit rate sits to
// the right of the tok/s meter in both states.
//
// Uses raw ANSI codes matching claude-statusline.sh so the palette matches
// the terminal theme, not pi's internal theme.

import { execFileSync } from "node:child_process";
import { basename } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { linkWrap, registerActionUrlHandler } from "./lib/custom-ui.ts";
import {
	ensureOpencodeUsage,
	isOpencodeGoModel,
	opencodeUsage,
	type OpencodeUsage,
} from "./lib/opencode.ts";
import {
	PIN_URL,
	endpointFor,
	ensureEndpointData as ensureEndpointDataLib,
	installRoutingFetchPatch,
	openPinDialog,
	orPins,
	pinDisplayName,
	routing,
	setSharedUiCtx,
} from "./lib/openrouter.ts";

const BAR_WIDTH = 10;
const BRANCH_ICON = "\ue725"; // same git branch glyph as claude-statusline.sh

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const PURPLE = "\x1b[35m";
const BLUE = "\x1b[34m";

const TICK_MS = 120;

// Click targets for the routing expansion: the model name and the expanded
// info line carry ROUTING_URL (toggle), the expanded line carries PIN_URL
// (provider picker, owned by pin-provider.ts's lib) as a SIBLING span —
// OSC 8 does not stack, so the button must never be wrapped inside the
// line's link (fullscreen only — linkWrap is inert otherwise, and pi never
// sees the click in regular mode anyway).
const ROUTING_URL = "pi-action://statusline/routing";

// OpenRouter's billed cost for the captured routing line
function fmtRoutingCost(cost: number): string {
	if (cost === 0) return "$0";
	return `$${cost >= 0.01 ? cost.toFixed(2) : cost.toFixed(5)}`;
}

const RAINBOW = [RED, YELLOW, GREEN, CYAN, BLUE, PURPLE];
const LEVEL_COLORS: Record<string, string> = {
  low: YELLOW,
  medium: GREEN,
  high: BLUE,
  xhigh: PURPLE,
};

// green < 50%, yellow < 75%, red >= 75%
function pctColor(pct: number): string {
  if (pct < 50) return GREEN;
  if (pct < 75) return YELLOW;
  return RED;
}

// output tok/s: red < 30, yellow < 80, green >= 80
function tokColor(rate: number): string {
  if (rate < 30) return RED;
  if (rate < 80) return YELLOW;
  return GREEN;
}

// prompt-cache hit rate: green >= 80%, yellow >= 50%, red below
function hitColor(pct: number): string {
  if (pct >= 80) return GREEN;
  if (pct >= 50) return YELLOW;
  return RED;
}

// Session-wide prompt-cache hit rate over the current branch: cached prompt
// tokens vs all prompt tokens (non-cache input + cache reads + cache writes;
// writes count as misses — the first turn of a session always is one).
// Returns null until some assistant usage exists (e.g. a brand-new session).
// liveRead/livePrompt fold in the in-flight request's input-side usage, which
// isn't in the branch yet (message_end fires before persistence).
function cacheHitPct(ctx: any, liveRead = 0, livePrompt = 0): number | null {
  let read = 0;
  let prompt = 0;
  for (const e of ctx.sessionManager.getBranch()) {
    if (e.type === "message" && e.message.role === "assistant") {
      const u = e.message.usage;
      if (!u) continue;
      read += u.cacheRead ?? 0;
      prompt += (u.cacheRead ?? 0) + (u.input ?? 0) + (u.cacheWrite ?? 0);
    }
  }
  read += liveRead;
  prompt += livePrompt;
  if (prompt === 0) return null;
  return (read / prompt) * 100;
}

function bar(pct: number): string {
  const filled = Math.min(BAR_WIDTH, Math.round((pct / 100) * BAR_WIDTH));
  const empty = BAR_WIDTH - filled;
  return pctColor(pct) + "█".repeat(filled) + DIM + "░".repeat(empty) + RESET;
}

function meter(label: string, pct: number, resetSuffix = ""): string {
  return `${BOLD}${CYAN}${label}${RESET} ${bar(pct)} ${pctColor(pct)}${BOLD}${pct}%${RESET}${resetSuffix}`;
}

// Same style as reset_label in claude-statusline.sh (the rate-limit timers).
function dimPart(text: string): string {
  return `${DIM}${text}${RESET}`;
}

function rainbowLabel(label: string, shift: number): string {
  let out = "";
  for (let i = 0; i < label.length; i++) {
    const c = RAINBOW[(((i - shift) % RAINBOW.length) + RAINBOW.length) % RAINBOW.length];
    out += `${BOLD}${c}${label[i]}`;
  }
  return `${out}${RESET}`;
}

function modelPart(model: { id: string; name?: string } | undefined): string {
  if (!model?.id) return "";
  // Prefer the registry display name, minus the "Vendor: " prefix (e.g.
  // "Z.ai: GLM 5.3 Flash" -> "GLM 5.3 Flash"), with dashes as spaces
  // ("Kimi-K2.5" -> "Kimi K2.5")
  const display = (model.name ?? model.id).replace(/^[^:]+:\s+/, "").replaceAll("-", " ");
  return `${BOLD}${PURPLE}◆ ${display}${RESET}`;
}

function sessionSpend(ctx: any): number {
  let total = 0;
  for (const e of ctx.sessionManager.getBranch()) {
    if (e.type === "message" && e.message.role === "assistant") {
      total += e.message.usage?.cost?.total ?? 0;
    }
  }
  return total;
}

function fmtDuration(ms: number): string {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
}

// Same style as reset_label in claude-statusline.sh (the rate-limit timers):
// a dimmed countdown to the window reset, appended after the meter. A days
// tier is added on top for windows longer than the shell script's 7-day max
// (the Go plan's monthly window resets ~30 days out).
function resetLabel(resetsAt: string | undefined): string {
  if (!resetsAt) return "";
  const diff = (Date.parse(resetsAt) - Date.now()) / 1000;
  if (!Number.isFinite(diff) || diff <= 0) return "";
  if (diff >= 86400)
    return ` ${DIM}${Math.floor(diff / 86400)}d${String(Math.floor((diff % 86400) / 3600)).padStart(2, "0")}h${RESET}`;
  if (diff >= 3600)
    return ` ${DIM}${Math.floor(diff / 3600)}h${String(Math.floor((diff % 3600) / 60)).padStart(2, "0")}m${RESET}`;
  if (diff >= 60) return ` ${DIM}${Math.floor(diff / 60)}m${RESET}`;
  return ` ${DIM}${Math.floor(diff)}s${RESET}`;
}

// Moon-phase emoji for the monthly meter: the rendered phase tracks the
// real moon. Sun and moon ecliptic longitudes from the compact trig
// approximations SunCalc uses (github.com/mourner/suncalc, BSD) — their
// difference is the phase angle, accurate to well under a degree, far
// beyond what an 8-emoji scale can express. The old mean-synodic-month
// trick drifted ~1 day and sat on the 🌑/🌒 boundary half the time.
const RAD = Math.PI / 180;
const MOON_PHASE_EMOJI = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"];

function moonEmoji(now = Date.now()): string {
  // days since J2000 (suncalc's toDays)
  const d = now / 86400000 - 0.5 + 2440588 - 2451545;
  const sunM = RAD * (357.5291 + 0.98560028 * d);
  const sunL =
    RAD * (280.46 + 0.9856474 * d) +
    RAD * 1.9148 * Math.sin(sunM) +
    RAD * 0.02 * Math.sin(2 * sunM);
  const moonM = RAD * (134.963 + 13.064993 * d);
  const moonL = RAD * (218.316 + 13.176396 * d) + RAD * 6.289 * Math.sin(moonM);
  // 0 new · ¼ first quarter · ½ full · ¾ last quarter
  const phase = ((((moonL - sunL) / (2 * Math.PI)) % 1) + 1) % 1;
  return MOON_PHASE_EMOJI[Math.round(phase * 8) % 8];
}

function repoName(cwd: string): string {
  try {
    const url = execFileSync("git", ["remote", "get-url", "origin"], {
      cwd,
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim();
    return basename(url).replace(/\.git$/, "");
  } catch {
    return basename(cwd);
  }
}

export default function statuslineExtension(pi: ExtensionAPI) {
  let enabled = false;
  let tuiRef: { requestRender(): void } | null = null;
  let cachedRepo: string | null = null;
  let uiCtx: any = null;

  // Quota refresh when the Go usage line is (or may be) visible. The
  // render path also calls ensure, but message_end is where spending
  // actually moved the bars.
  const ensureGoUsage = (ctx: any) =>
    ensureOpencodeUsage(ctx?.model, () => tuiRef?.requestRender());

  // Routing expansion: clicking the model name (or the info line itself)
  // toggles a second footer line describing the OpenRouter routing. Clicks
  // arrive as OSC 8 pi-action links resolved by the custom-ui suite's
  // openUrl patch (fullscreen only); the handler is registered on the lib's
  // globalThis registry so it survives /reload as long as the URL is ours.
  let expanded = false;

  const ensureEndpointData = () => ensureEndpointDataLib(uiCtx?.model, () => tuiRef?.requestRender());

  // id-keyed so a /reload replaces this registration instead of stacking a
  // stale closure that would swallow the click (the dead instance's handler
  // is consulted first and flips state nothing renders anymore)
  registerActionUrlHandler(
    (url) => {
      if (url === ROUTING_URL) {
        expanded = !expanded;
        if (expanded) {
          ensureEndpointData();
          ensureGoUsage(uiCtx);
        }
        return true;
      }
      // fallbacks for the pin URLs — normally owned by pin-provider.ts via
      // the lib (its handler usually claims them first)
      if (url === PIN_URL) {
        expanded = true;
        ensureEndpointData();
        ensureGoUsage(uiCtx);
        void openPinDialog(uiCtx, { onRequestRender: () => tuiRef?.requestRender() });
        return true;
      }
      const sortMatch = /^pi-action:\/\/pin-provider\/sort\/(\d)$/.exec(url);
      if (sortMatch) {
        const sink = (globalThis as Record<string, unknown>).__piOpenrouterSortSink as
          | ((col: number) => void)
          | undefined;
        sink?.(Number(sortMatch[1]));
        return true;
      }
      return false;
    },
    "statusline",
  );

  installRoutingFetchPatch();
  // the lib's dialog needs a session ctx even when opened from its own
  // action-URL handler; the footer holds the freshest one
  pi.on("session_start", (_event, ctx) => setSharedUiCtx(ctx));
  routing().bump = () => tuiRef?.requestRender();

  // Animation state: a tick timer that runs while the agent is working
  // (drives the max-effort rainbow and keeps the turn timer ticking).
  let waiting = false;
  let timer: ReturnType<typeof setInterval> | null = null;
  let tickCount = 0;

  // tok/s + turn timer state. rate is a rolling rate over the last
  // RATE_WINDOW_MS of output tokens; turnTokens is a strictly monotonic
  // cumulative counter (samples are only ever pushed upwards, so the rate
  // can never go negative); frozen holds the settled turn's summary.
  const RATE_WINDOW_MS = 3000;
  let turnStart: number | null = null;
  let elapsedMs = 0;
  let samples: { t: number; tokens: number }[] = [];
  let rate: number | null = null;
  // per-message accounting: usage.output restarts at 0 for each assistant
  // message in the turn, and some providers report non-cumulative or
  // decreasing values mid-stream, so reconcile per message and clamp.
  let curMsgKey: string | number | null = null;
  let msgStart = 0; // turnTokens when this message started
  let msgCounted = 0; // highest usage.output seen for this message
  let msgEst = 0; // estimate-based tokens for this message
  let msgStreamStart: number | null = null; // first token of this message
  let lastTokT: number | null = null; // time of the most recent token
  let streamMs = 0; // time spent actually receiving tokens (TTFT excluded)
  let turnTokens = 0;
  // in-flight request's input-side usage for the cache hit meter (overwritten
  // per message_update; zeroed on message_end so it never double-counts with
  // the branch, where the message lands right after)
  let liveRead = 0;
  let livePrompt = 0;
  // starts with a placeholder so the meter is visible before the first turn
  let frozen: { rate: number | null; ms: number } = { rate: null, ms: 0 };
  let lastTokRender = 0;

  // Close the current message's streaming span. Closes at the last token's
  // timestamp — NOT "now" — because by the time the next message's first
  // update arrives, tool execution and the provider round-trip have already
  // happened, and counting them would deflate the streaming average.
  const closeStreamingSpan = () => {
    if (msgStreamStart != null && lastTokT != null && lastTokT > msgStreamStart) {
      streamMs += lastTokT - msgStreamStart;
    }
    msgStreamStart = null;
  };

  const syncTimer = (ctx?: any) => {
    const wanted = waiting; // tick while working: rainbow + turn timer refresh
    if (wanted && !timer) {
      timer = setInterval(() => {
        tickCount++;
        if (waiting && turnStart != null) {
          elapsedMs = Date.now() - turnStart;
          // let the rate expire when nothing has streamed for a while
          const last = samples[samples.length - 1];
          if (last && Date.now() - last.t > RATE_WINDOW_MS) rate = null;
        }
        tuiRef?.requestRender();
      }, TICK_MS);
      // never keep a process alive just for the animation
      timer.unref?.();
    } else if (!waiting && timer) {
      clearInterval(timer);
      timer = null;
    }
  };

  const setFooter = (ctx: any, on: boolean) => {
    uiCtx = ctx;
    ctx.ui.setFooter(
      on
        ? (tui: any, _theme: any, footerData: any) => {
            tuiRef = tui;
            const unsub = footerData.onBranchChange(() => {
              cachedRepo = null;
              tui.requestRender();
            });

            return {
              dispose: () => {
                cachedRepo = null;
                unsub();
              },
              invalidate() {},
              render(width: number): string[] {
                const parts: string[] = [];

                // model and effort sit together, like model_part in the Claude script
                // (the model chip carries the routing toggle link)
                const modelBits: string[] = [];
                const model = modelPart(ctx.model);
                if (model) modelBits.push(linkWrap(model, ROUTING_URL));

                const level = ctx.thinkingLevel;
                if (level === "max") {
                  modelBits.push(rainbowLabel("max", waiting ? tickCount : 0));
                } else if (level) {
                  const color = LEVEL_COLORS[level];
                  modelBits.push(
                    color
                      ? `${BOLD}${color}${level}${RESET}`
                      : `${DIM}${level}${RESET}`,
                  );
                }
                if (modelBits.length) parts.push(modelBits.join(" "));

                const usage = ctx.getContextUsage();
                if (usage?.percent != null) {
                  parts.push(meter("📁 ctx", Math.round(usage.percent)));
                }

                // tok/s + turn timer between the ctx bar and the spend meter;
                // the cache hit rate gets its own column after them (session-
                // cumulative, so it reads the same live and frozen)
                const hitPct = cacheHitPct(ctx, liveRead, livePrompt);
                const cacheBit =
                  hitPct != null
                    ? `${hitColor(hitPct)}🎯 ${Math.round(hitPct)}% cache${RESET}`
                    : `${DIM}🎯 --% cache${RESET}`;
                if (waiting) {
                  const bits: string[] = [];
                  if (rate != null) {
                    bits.push(
                      `${tokColor(rate)}${BOLD}⚡ ${Math.round(rate)} tok/s${RESET}`,
                    );
                  } else {
                    // pending until the first rate window fills
                    bits.push(`${DIM}⚡ -- tok/s${RESET}`);
                  }
                  if (elapsedMs > 0) {
                    bits.push(`${DIM}${fmtDuration(elapsedMs)}${RESET}`);
                  }
                  parts.push(bits.join(`${DIM} · ${RESET}`));
                  parts.push(cacheBit);
                } else {
                  const rateBit =
                    frozen.rate != null
                      ? `${tokColor(frozen.rate)}⚡ ${Math.round(frozen.rate)} tok/s${RESET}`
                      : `${DIM}⚡ -- tok/s${RESET}`;
                  const durBit = `${DIM}${fmtDuration(frozen.ms)}${RESET}`;
                  parts.push(rateBit + `${DIM} · ${RESET}` + durBit);
                  parts.push(cacheBit);
                }

                parts.push(dimPart(`💵 $${sessionSpend(ctx).toFixed(2)}`));

                if (!cachedRepo) cachedRepo = repoName(ctx.cwd);

                let repo = `${BOLD}${YELLOW}${cachedRepo}${RESET}`;
                const branch = footerData.getGitBranch();
                if (branch) {
                  repo += ` ${YELLOW}${BRANCH_ICON} ${branch}${RESET}`;
                }
                parts.push(repo);

                // single left-aligned line, like the Claude statusline
                const line = parts.join(`${DIM}  |  ${RESET}`);
                const lines = [truncateToWidth(line, width)];
                const routed = routing(); // before the local `routing` below shadows the lib import
                if (expanded) {
                  const model = ctx.model as { provider?: string; id?: string; baseUrl?: string } | undefined;
                  // OpenCode Go: the plan's own limit windows replace the
                  // OpenRouter routing info there is nothing to route
                  if (isOpencodeGoModel(model)) {
                    ensureGoUsage(ctx);
                    lines.push(
                      truncateToWidth(linkWrap(goUsageLine(), ROUTING_URL), width),
                    );
                  } else {
                  const routing = truncateToWidth(linkWrap(routingLine(), ROUTING_URL), width);
                  // sibling span — the button must not sit inside the line's link
                  const button =
                    model?.provider === "openrouter" && model.id ? linkWrap(" (change provider)", PIN_URL) : "";
                  // endpoint metadata still loading: the … trails the whole line
                  const { loading } = endpointFor(model?.id ?? "", routed.provider);
                  const loadingBit = loading ? `${DIM} …${RESET}` : "";
                  lines.push(truncateToWidth(routing + button + loadingBit, width));
                  }
                }
                return lines;
              },
            };
          }
        : undefined,
    );
  };

  const toggle = (ctx: any) => {
    enabled = !enabled;
    setFooter(ctx, enabled);
    ctx.ui.notify(enabled ? "Statusline enabled" : "Default footer restored", "info");
  };

  // Second footer line: where OpenRouter is routing the current model.
  // Provider name + billed cost are captured from the live stream (fetch
  // patch above); quantization/uptime/throughput come from OpenRouter's
  // public endpoints API, matched against the routed provider.
  const routingLine = (): string => {
    const model = uiCtx?.model;
    if (model?.provider !== "openrouter" || !model.id) {
      return `${DIM}↳ routing: ${model?.provider ?? "?"}${RESET}`;
    }
    const r = routing();
    const pin = orPins()[model.id];
    if (r.provider === null && r.cost === null && !pin) {
      return `${DIM}↳ openrouter · no routing captured this session${RESET}`;
    }
    const bits: string[] = [];
    if (r.provider !== null) bits.push(`${BOLD}${CYAN}↳ ${r.provider}${RESET}`);
    const { data: ep } = endpointFor(model.id, r.provider);
    if (ep) {
      if (ep.quantization) bits.push(`${PURPLE}${String(ep.quantization).toUpperCase()}${RESET}`);
      if (ep.uptime_last_1d != null) bits.push(`${GREEN}${ep.uptime_last_1d.toFixed(2)}% up${RESET}`);
      if (ep.throughput_last_30m != null) bits.push(`${YELLOW}${Math.round(ep.throughput_last_30m)} tok/s${RESET}`);
    }
    if (r.cost != null) bits.push(`${YELLOW}${fmtRoutingCost(r.cost)}${RESET}`);
    if (pin) {
      const name = pinDisplayName(model.id, pin);
      bits.push(`${BOLD}${GREEN}📌 pin: ${name}${RESET}`);
    }
    return bits.join(`${DIM} · ${RESET}`);
  };

  // Second footer line for OpenCode Go models: the plan's three
  // dollar-metered limit windows (rolling 5h, weekly, monthly) as ctx-style
  // bars, straight from the server's quota endpoint. The whole line carries
  // the routing toggle link, so clicking it still collapses.
  const goUsageLine = (): string => {
    const u = opencodeUsage();
    if (!u.data && !u.loading) return `${DIM}↳ OpenCode Go: usage unavailable${RESET}`;
    const windows: [keyof OpencodeUsage, string][] = [
      // same icons as the claude statusline's rate-limit meters
      ["rolling", "⌚ 5h"],
      ["weekly", "📅 wk"],
      ["monthly", `${moonEmoji()} mo`],
    ];
    const bits = windows.map(([key, label]) => {
      const w = u.data?.[key];
      const pct = w?.percent;
      if (typeof pct !== "number" || !Number.isFinite(pct)) {
        return `${DIM}${label} --%${RESET}`;
      }
      return meter(label, Math.round(pct), resetLabel(w?.resetsAt));
    });
    return `${DIM}↳ OpenCode Go${RESET} ${DIM}·${RESET} ` + bits.join(`${DIM} · ${RESET}`);
  };

  pi.registerCommand("statusbar", {
    description: "Toggle the statusline footer",
    handler: async (_args, ctx) => toggle(ctx),
  });

  // Animation window: from the moment a run starts until it fully settles
  // (including retries and queued follow-ups).
  pi.on("agent_start", async (_event, ctx) => {
    waiting = true;
    turnStart = Date.now();
    elapsedMs = 0;
    samples = [];
    rate = null;
    turnTokens = 0;
    curMsgKey = null;
    msgStart = 0;
    msgCounted = 0;
    msgEst = 0;
    msgStreamStart = null;
    lastTokT = null;
    streamMs = 0;
    liveRead = 0;
    livePrompt = 0;
    frozen = { rate: null, ms: 0 };
    syncTimer(ctx);
  });

  pi.on("agent_settled", async (_event, ctx) => {
    waiting = false;
    if (turnStart != null) elapsedMs = Date.now() - turnStart;
    turnStart = null;
    closeStreamingSpan();
    // turn average over time actually spent streaming (first token of each
    // message to its last), so TTFT/tool latency doesn't drag it down
    const avg =
      turnTokens > 0 && streamMs > 500 ? turnTokens / (streamMs / 1000) : null;
    frozen = { rate: avg, ms: elapsedMs };
    syncTimer(ctx);
  });

  // Track streamed output tokens for the tok/s meter. The partial message
  // on each update carries live usage.output; fall back to a ~4 chars/token
  // estimate when the provider doesn't stream usage.
  pi.on("message_update", async (event) => {
    if (!waiting || turnStart == null) return;
    const now = Date.now();
    elapsedMs = now - turnStart;

    const msg = event.message as any;
    const raw = msg?.usage?.output ?? 0;
    const ev = (event as any).assistantMessageEvent;

    // live input-side usage for the cache hit meter (0 until the provider
    // reports it, which for most providers happens with the usage stream)
    const lu = msg?.usage;
    liveRead = lu?.cacheRead ?? 0;
    livePrompt = liveRead + (lu?.input ?? 0) + (lu?.cacheWrite ?? 0);

    // per-message accounting: usage.output is per assistant message and
    // can even decrease mid-stream with some providers, so track the
    // current message separately and keep the turn total monotonic
    const mid = msg?.responseId ?? msg?.timestamp ?? null;
    if (mid !== curMsgKey) {
      closeStreamingSpan();
      curMsgKey = mid;
      msgStart = turnTokens;
      msgCounted = 0;
      msgEst = 0;
    }
    if (raw > msgCounted) msgCounted = raw;
    if (ev?.type === "text_delta" || ev?.type === "thinking_delta") {
      // ~4 chars/token estimate for providers that don't stream usage
      msgEst += Math.ceil(ev.delta.length / 4);
    }
    // real usage is authoritative when the provider reports it; the
    // char-based estimate only fills in when usage isn't streaming
    const cur = msgCounted > 0 ? msgCounted : msgEst;
    const cand = msgStart + cur;
    if (cand > turnTokens) {
      if (msgStreamStart == null) msgStreamStart = now; // first token
      lastTokT = now;
      turnTokens = cand;
      const last = samples[samples.length - 1];
      if (!last || turnTokens > last.tokens) samples.push({ t: now, tokens: turnTokens });
    }

    // rolling rate over the last RATE_WINDOW_MS (keep one baseline sample
    // just outside the window so short bursts still average). A baseline
    // much older than the window means a streaming gap (tool call, retry) —
    // drop it so the resumed rate isn't diluted across the dead time.
    while (samples.length > 2 && now - samples[1].t > RATE_WINDOW_MS) {
      samples.shift();
    }
    while (
      samples.length > 1 &&
      now - samples[0].t > RATE_WINDOW_MS + 2000
    ) {
      samples.shift();
    }
    if (samples.length >= 2) {
      const first = samples[0];
      const last = samples[samples.length - 1];
      const dt = (last.t - first.t) / 1000;
      if (dt >= 0.5) rate = (last.tokens - first.tokens) / dt;
    }

    // throttle redraws — message_update fires per delta
    if (now - lastTokRender > 100) {
      lastTokRender = now;
      tuiRef?.requestRender();
    }
  });

  // Redraw when the context window or spend changes after each response.
  // Zero the live cache-usage tracker: the completed message is about to be
  // persisted into the branch, so counting both would double it.
  pi.on("message_end", async () => {
    liveRead = 0;
    livePrompt = 0;
    if (expanded) ensureGoUsage(uiCtx);
    tuiRef?.requestRender();
  });

  // Refresh the effort label immediately when the level changes.
  pi.on("thinking_level_select", async (_event, ctx) => {
    tuiRef?.requestRender();
    syncTimer(ctx);
  });

  // Model switches may leave the endpoints cache pointing at the old model.
  pi.on("model_select", async (_event, ctx) => {
    if (!expanded) return;
    uiCtx = ctx;
    ensureEndpointData();
    tuiRef?.requestRender();
  });

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui" || enabled) return;
    enabled = true;
    setFooter(ctx, true);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    waiting = false;
    turnStart = null;
    syncTimer(ctx);
    tuiRef = null;
  });
}
