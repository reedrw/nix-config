// Pi statusline — port of the Claude Code statusline.
// Shows the model, thinking level (effort), a context-usage meter, session
// spend, and the git repo + branch. Toggle with /statusbar; auto-enables
// in TUI sessions. (The Claude 5h/7d rate-limit meters have no pi equivalent
// and are replaced by the spend indicator.)
//
// While the agent is working (between agent_start and agent_settled) the
// effort label animates: the level's color pulses through grey text, and
// "maximum" gets a rolling rainbow. When idle, everything is static.
//
// Uses raw ANSI codes matching claude-statusline.sh so the palette matches
// the terminal theme, not pi's internal theme.

import { execFileSync } from "node:child_process";
import { basename } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

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

  // Animation state: a tick timer that runs only while the agent is working
  // at max effort (the only animated label).
  let waiting = false;
  let timer: ReturnType<typeof setInterval> | null = null;
  let tickCount = 0;

  const syncTimer = (ctx?: any) => {
    const wanted = waiting && ctx?.thinkingLevel === "max";
    if (wanted && !timer) {
      timer = setInterval(() => {
        tickCount++;
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
                const modelBits: string[] = [];
                const model = modelPart(ctx.model);
                if (model) modelBits.push(model);

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
                return [truncateToWidth(line, width)];
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

  pi.registerCommand("statusbar", {
    description: "Toggle the statusline footer",
    handler: async (_args, ctx) => toggle(ctx),
  });

  // Animation window: from the moment a run starts until it fully settles
  // (including retries and queued follow-ups).
  pi.on("agent_start", async (_event, ctx) => {
    waiting = true;
    syncTimer(ctx);
  });

  pi.on("agent_settled", async (_event, ctx) => {
    waiting = false;
    syncTimer(ctx);
  });

  // Redraw when the context window or spend changes after each response.
  pi.on("message_end", async () => {
    tuiRef?.requestRender();
  });

  // Refresh the effort label immediately when the level changes.
  pi.on("thinking_level_select", async (_event, ctx) => {
    tuiRef?.requestRender();
    syncTimer(ctx);
  });

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui" || enabled) return;
    enabled = true;
    setFooter(ctx, true);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    waiting = false;
    syncTimer(ctx);
    tuiRef = null;
  });
}
