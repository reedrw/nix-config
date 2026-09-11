// Pi statusline — port of the Claude Code statusline.
// Shows the model, thinking level (effort), a context-usage meter, session
// spend, a prompt-cache hit rate, and the git repo + branch. Toggle with
// /statusbar; auto-enables
// in TUI sessions. (The Claude 5h/7d rate-limit meters have no pi equivalent
// and are replaced by the spend indicator.)
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

// Click target for the routing expansion: the model name and the expanded
// info line both carry this OSC 8 pi-action link (fullscreen only — linkWrap
// is inert otherwise, and pi never sees the click in regular mode anyway).
const ROUTING_URL = "pi-action://statusline/routing";
const ENDPOINTS_TTL_MS = 5 * 60_000;
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

function meter(label: string, pct: number): string {
  return `${BOLD}${CYAN}${label}${RESET} ${bar(pct)} ${pctColor(pct)}${BOLD}${pct}%${RESET}`;
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
  // "Z.ai: GLM 5.3 Flash" -> "GLM 5.3 Flash")
  const display = (model.name ?? model.id).replace(/^[^:]+:\s+/, "");
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

// ── OpenRouter routing capture ────────────────────────────────
//
// pi-ai's openai-completions parser drops OpenRouter's routing metadata: the
// `provider` field on every SSE chunk and the actual billed `usage.cost` on
// the final usage chunk. Patch globalThis.fetch once (globalThis flag —
// /reload re-imports this module and would otherwise chain a second patch)
// and tee the SSE of openrouter.ai chat-completions responses to harvest
// both. The tee'd branch is drained in the background and never disturbs
// pi's own read of the original body. State lives on globalThis so a
// reloaded instance reads what the surviving patch captures.

interface OrRouting {
	provider: string | null;
	cost: number | null; // OpenRouter's billed cost for the latest request
	at: number; // Date.now() of the last captured request
	bump?: () => void; // current instance's render nudge
}

const ROUTING_KEY = "__piStatuslineRouting";

function routing(): OrRouting {
	const gt = globalThis as Record<string, unknown>;
	let r = gt[ROUTING_KEY] as OrRouting | undefined;
	if (!r) {
		r = { provider: null, cost: null, at: 0 };
		gt[ROUTING_KEY] = r;
	}
	return r;
}

function ingestRoutingChunk(chunk: any): void {
	const provider = typeof chunk?.provider === "string" && chunk.provider !== "" ? chunk.provider : null;
	const raw = chunk?.usage?.cost ?? null;
	const cost = typeof raw === "number" ? raw : typeof raw === "string" && raw !== "" ? Number(raw) : null;
	if (provider === null && !(cost != null && Number.isFinite(cost))) return;
	const r = routing();
	if (provider !== null) r.provider = provider;
	if (cost != null && Number.isFinite(cost)) r.cost = cost;
	r.at = Date.now();
	r.bump?.();
}

// Consume a tee'd response body and feed every SSE data line (or a JSON
// fallback) to ingestRoutingChunk. Aborts and network errors are expected
// here (pi may cancel the stream) — swallow everything.
function drainRoutingClone(clone: Response): void {
	const ct = clone.headers.get("content-type") ?? "";
	if (ct.includes("text/event-stream") && clone.body) {
		void (async () => {
			try {
				const reader = clone.body!.getReader();
				const decoder = new TextDecoder();
				let buf = "";
				for (;;) {
					const { done, value } = await reader.read();
					if (done) break;
					buf += decoder.decode(value, { stream: true });
					let nl: number;
					while ((nl = buf.indexOf("\n")) !== -1) {
						const line = buf.slice(0, nl).trim();
						buf = buf.slice(nl + 1);
						if (!line.startsWith("data:")) continue;
						const data = line.slice(5).trim();
						if (data === "" || data === "[DONE]") continue;
						try {
							ingestRoutingChunk(JSON.parse(data));
						} catch {
							// partial/invalid SSE line — ignore
						}
					}
				}
			} catch {
				// aborted stream — stop harvesting
			}
		})();
	} else if (ct.includes("json")) {
		void clone
			.text()
			.then((text) => ingestRoutingChunk(JSON.parse(text)))
			.catch(() => {});
	}
}

const OPENROUTER_URL_RE = /openrouter\.ai\/api\/v1\/chat\/completions/;

function installRoutingFetchPatch(): void {
	const gt = globalThis as Record<string, unknown> & { fetch: typeof fetch };
	const flag = gt as { __piStatuslineFetchPatched?: boolean };
	if (flag.__piStatuslineFetchPatched) return;
	flag.__piStatuslineFetchPatched = true;
	const original = gt.fetch.bind(gt);
	gt.fetch = async (input: any, init?: any) => {
		const url = typeof input === "string" ? input : input instanceof URL ? input.href : (input?.url as string) ?? "";
		const res = await original(input, init);
		try {
			if (OPENROUTER_URL_RE.test(url) && res.ok) drainRoutingClone(res.clone());
		} catch {
			// teeing must never break the real request
		}
		return res;
	};
}

// ── OpenRouter endpoint metadata (public, no auth) ────────────
//
// The endpoints API lists every routed provider for a model with its
// quantization, 1-day uptime, and provider-reported throughput. We match the
// entry against the routed provider captured from the stream above.

let endpointCache: { modelId: string; at: number; data: any[] | null } | null = null;
let endpointLoad: Promise<void> | null = null;

function loadEndpointData(modelId: string, onDone: () => void): Promise<void> {
	endpointCache = { modelId, at: Date.now(), data: null };
	const load = (async () => {
		try {
			const res = await fetch(`https://openrouter.ai/api/v1/models/${modelId}/endpoints`);
			if (!res.ok) throw new Error(String(res.status));
			const body = (await res.json()) as any;
			// the whole list is cached; the entry matching the routed provider is
			// picked lazily at render time (routing can change between loads)
			const endpoints = (body?.data?.endpoints ?? []) as any[];
			if (endpointCache && endpointCache.modelId === modelId) {
				endpointCache.data = endpoints.length > 0 ? endpoints : null;
			}
		} catch {
			if (endpointCache && endpointCache.modelId === modelId) endpointCache.data = null;
		} finally {
			onDone();
		}
	})();
	endpointLoad = load.finally(() => {
		endpointLoad = null;
	});
	return endpointLoad;
}

function endpointFor(modelId: string, provider: string | null): { data: any | null; loading: boolean } {
	if (!endpointCache || endpointCache.modelId !== modelId) return { data: null, loading: false };
	if (!Array.isArray(endpointCache.data)) return { data: null, loading: endpointLoad !== null };
	if (provider === null) return { data: null, loading: false };
	const match = endpointCache.data.find((e: any) => e.provider_name === provider);
	return { data: match ?? null, loading: false };
}

function fmtRoutingCost(cost: number): string {
	if (cost === 0) return "$0";
	return `$${cost >= 0.01 ? cost.toFixed(2) : cost.toFixed(5)}`;
}

export default function statuslineExtension(pi: ExtensionAPI) {
  let enabled = false;
  let tuiRef: { requestRender(): void } | null = null;
  let cachedRepo: string | null = null;
  let uiCtx: any = null;

  // Routing expansion: clicking the model name (or the info line itself)
  // toggles a second footer line describing the OpenRouter routing. Clicks
  // arrive as OSC 8 pi-action links resolved by the custom-ui suite's
  // openUrl patch (fullscreen only); the handler is registered on the lib's
  // globalThis registry so it survives /reload as long as the URL is ours.
  let expanded = false;

  const ensureEndpointData = () => {
    const model = uiCtx?.model;
    if (!model || model.provider !== "openrouter" || !model.id) return;
    const fresh =
      endpointCache && endpointCache.modelId === model.id && Date.now() - endpointCache.at < ENDPOINTS_TTL_MS;
    if (fresh) return;
    void loadEndpointData(model.id, () => tuiRef?.requestRender());
  };

  registerActionUrlHandler((url) => {
    if (url !== ROUTING_URL) return false;
    expanded = !expanded;
    if (expanded) ensureEndpointData();
    return true;
  });

  installRoutingFetchPatch();
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
                if (expanded) lines.push(truncateToWidth(linkWrap(routingLine(), ROUTING_URL), width));
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
      return `${DIM}↳ routing: ${model?.provider ?? "?"} (not OpenRouter)${RESET}`;
    }
    const r = routing();
    if (r.provider === null && r.cost === null) {
      return `${DIM}↳ openrouter · no routing captured this session${RESET}`;
    }
    const bits: string[] = [];
    bits.push(`${BOLD}${CYAN}↳ ${r.provider ?? "?"}${RESET}`);
    const { data: ep, loading } = endpointFor(model.id, r.provider);
    if (ep) {
      if (ep.quantization) bits.push(`${PURPLE}${String(ep.quantization).toUpperCase()}${RESET}`);
      if (ep.uptime_last_1d != null) bits.push(`${GREEN}${ep.uptime_last_1d.toFixed(2)}% up${RESET}`);
      if (ep.throughput_last_30m != null) bits.push(`${YELLOW}${Math.round(ep.throughput_last_30m)} tok/s${RESET}`);
    } else if (loading) {
      bits.push(`${DIM}…${RESET}`);
    }
    if (r.cost != null) bits.push(`${YELLOW}${fmtRoutingCost(r.cost)}${RESET}`);
    return bits.join(`${DIM} · ${RESET}`);
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
