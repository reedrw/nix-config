import type { AssistantMessage, AssistantMessageEvent } from "@earendil-works/pi-ai";
import { registerExtensionSettings } from "./shared-settings/index.ts";
import {
  VERSION,
  keyText,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { getKeybindings } from "@earendil-works/pi-tui";
import {
  configToRenderOptions,
  loadThinkingFoldConfig,
  saveThinkingFoldConfig,
  THINKING_FOLD_SETTINGS_NAMESPACE,
  type ThinkingFoldConfig,
} from "./config.ts";
import {
  createThinkingCursorLabel,
  DEFAULT_THINKING_CURSOR_LABEL,
  installThinkingFoldPatch,
  type ThinkingFoldPatchHandle,
} from "./renderer.ts";

const ITEM_TIMER_INTERVAL_MS = 1000;
const MIN_SUMMARY_CURSOR_MS = 1000;

export function endsThinkingPhase(type: AssistantMessageEvent["type"]): boolean {
  return (
    type === "thinking_end" ||
    type === "text_start" ||
    type === "text_delta" ||
    type === "toolcall_start" ||
    type === "toolcall_delta"
  );
}

export function remainingSummaryCursorMs(
  firstVisibleAt: number,
  completedAt: number,
  minimumMs = MIN_SUMMARY_CURSOR_MS,
): number {
  return Math.max(0, minimumMs - Math.max(0, completedAt - firstVisibleAt));
}

function restoreTimings(ctx: ExtensionContext, patch: ThinkingFoldPatchHandle): void {
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const message = entry.message;
    if (!message.content.some((block) => block.type === "thinking" && block.thinking.trim())) continue;

    const completedAt = Date.parse(entry.timestamp);
    const startedAt = Number.isFinite(message.timestamp) ? message.timestamp : completedAt;
    patch.setMessageTiming(message.timestamp, {
      startedAt: Math.min(startedAt, completedAt),
      completedAt,
    });
  }
}

function lineValues(current: number): string[] {
  return [...new Set([1, 3, 5, 8, 10, 15, 20, current])]
    .sort((left, right) => left - right)
    .map(String);
}

export default function (pi: ExtensionAPI) {
  let config = loadThinkingFoldConfig();
  let patch: ThinkingFoldPatchHandle | undefined;
  let removeInputListener: (() => void) | undefined;
  let itemTimer: ReturnType<typeof setInterval> | undefined;
  let summaryHoldTimer: ReturnType<typeof setTimeout> | undefined;
  let thinkingStartedAt: number | undefined;
  let lastItemTimerSecond = -1;
  let lastWorkingMessage: string | undefined;
  let summaryFirstVisibleAt: number | undefined;
  let holdingSummaryCursor = false;
  let currentAssistant: AssistantMessage | undefined;
  let sawThinkingInCurrentMessage = false;
  let thinkingCompleted = false;
  let patchError: string | undefined;

  try {
    patch = installThinkingFoldPatch(configToRenderOptions(config));
  } catch (error) {
    patchError = error instanceof Error ? error.message : String(error);
  }

  const stopItemTimer = () => {
    if (itemTimer) clearInterval(itemTimer);
    itemTimer = undefined;
  };

  const renderThinkingCursor = (ctx: ExtensionContext, now = Date.now()) => {
    if (
      ctx.mode !== "tui" ||
      thinkingStartedAt === undefined ||
      (thinkingCompleted && !holdingSummaryCursor) ||
      !currentAssistant ||
      !patch
    ) {
      return;
    }
    const label = createThinkingCursorLabel(currentAssistant, patch.options.mode);
    if (label === lastWorkingMessage) return;
    lastWorkingMessage = label;
    ctx.ui.setWorkingMessage(label);
  };

  const refreshItemTimer = (now = Date.now()) => {
    if (!patch || thinkingStartedAt === undefined || thinkingCompleted) return;
    const elapsedSecond = Math.floor(Math.max(0, now - thinkingStartedAt) / 1000);
    if (elapsedSecond === lastItemTimerSecond) return;
    lastItemTimerSecond = elapsedSecond;
    patch.tick(now);
  };

  const startItemTimer = (ctx: ExtensionContext) => {
    if (!patch || itemTimer || ctx.mode !== "tui") return;
    const now = Date.now();
    refreshItemTimer(now);
    renderThinkingCursor(ctx, now);
    itemTimer = setInterval(() => refreshItemTimer(), ITEM_TIMER_INTERVAL_MS);
  };

  const clearSummaryHold = () => {
    if (summaryHoldTimer) clearTimeout(summaryHoldTimer);
    summaryHoldTimer = undefined;
    holdingSummaryCursor = false;
  };

  const showResponding = (ctx: ExtensionContext) => {
    clearSummaryHold();
    stopItemTimer();
    lastWorkingMessage = "Responding...";
    ctx.ui.setWorkingMessage(lastWorkingMessage);
  };

  const applyConfig = (next: ThinkingFoldConfig, ctx: ExtensionContext) => {
    config = next;
    patch?.updateOptions(configToRenderOptions(config));
    try {
      saveThinkingFoldConfig(config);
    } catch (error) {
      ctx.ui.notify(
        `Failed to save thinking-fold settings: ${error instanceof Error ? error.message : String(error)}`,
        "error",
      );
    }
    if (sawThinkingInCurrentMessage) {
      lastWorkingMessage = undefined;
      renderThinkingCursor(ctx);
    }
  };

  registerExtensionSettings(pi, {
    namespace: THINKING_FOLD_SETTINGS_NAMESPACE,
    title: "Thinking Fold",
    settings: () => [
      {
        id: "foldThreshold",
        label: "Fold after lines",
        description: "Show at most this many terminal-visible lines in a preview",
        currentValue: String(config.foldThreshold),
        values: lineValues(config.foldThreshold),
      },
      {
        id: "streamingBehavior",
        label: "While thinking",
        description: "Auto hides summaries and previews traces while they stream",
        currentValue: config.streamingBehavior,
        values: ["auto", "preview", "collapse"],
      },
      {
        id: "completedBehavior",
        label: "After thinking",
        description: "Auto hides completed content for every model",
        currentValue: config.completedBehavior,
        values: ["auto", "collapse", "preview", "full"],
      },
    ],
    onChange: (id, value, ctx) => {
      if (id === "foldThreshold") {
        applyConfig({ ...config, foldThreshold: Number(value) }, ctx);
      } else if (
        id === "streamingBehavior" &&
        (value === "auto" || value === "preview" || value === "collapse")
      ) {
        applyConfig({ ...config, streamingBehavior: value }, ctx);
      } else if (
        id === "completedBehavior" &&
        (value === "auto" || value === "collapse" || value === "preview" || value === "full")
      ) {
        applyConfig({ ...config, completedBehavior: value }, ctx);
      }
    },
  });

  pi.on("session_start", (_event, ctx) => {
    if (patchError) {
      if (ctx.hasUI) {
        ctx.ui.notify(`thinking-fold disabled on Pi ${VERSION}: ${patchError}`, "warning");
      }
      return;
    }
    if (!patch || ctx.mode !== "tui") return;

    const toggleKey = keyText("app.thinking.toggle") || "ctrl+t";
    patch.updateOptions({ ...configToRenderOptions(config), toggleKey });
    restoreTimings(ctx, patch);

    removeInputListener?.();
    removeInputListener = ctx.ui.onTerminalInput((data) => {
      if (!patch || !getKeybindings().matches(data, "app.thinking.toggle")) return;

      patch.toggle();
      return { consume: true };
    });
  });

  pi.on("message_start", (event, ctx) => {
    if (event.message.role !== "assistant" || ctx.mode !== "tui" || !patch) return;
    currentAssistant = event.message;
    sawThinkingInCurrentMessage = false;
    thinkingCompleted = false;
    clearSummaryHold();
    summaryFirstVisibleAt = undefined;
    thinkingStartedAt = Date.now();
    lastItemTimerSecond = -1;
    lastWorkingMessage = undefined;
    patch.beginMessage(event.message, thinkingStartedAt);
    renderThinkingCursor(ctx, thinkingStartedAt);
  });

  pi.on("message_update", (event, ctx) => {
    if (event.message.role !== "assistant" || ctx.mode !== "tui" || !patch) return;
    currentAssistant = event.message;

    const hasThinking = event.message.content.some((block) => block.type === "thinking");
    if (hasThinking) {
      sawThinkingInCurrentMessage = true;
      const now = Date.now();
      const cursorLabel = createThinkingCursorLabel(event.message, patch.options.mode);
      if (cursorLabel !== DEFAULT_THINKING_CURSOR_LABEL) summaryFirstVisibleAt ??= now;
      startItemTimer(ctx);
      renderThinkingCursor(ctx, now);
    }

    if (
      sawThinkingInCurrentMessage &&
      !thinkingCompleted &&
      endsThinkingPhase(event.assistantMessageEvent.type)
    ) {
      // OpenAI-compatible providers such as DeepSeek may emit thinking_end only
      // after the entire response stream. Freeze the duration as soon as actual
      // text or a tool call begins, then ignore the provider's late event.
      const completedAt = Date.now();
      patch.completeMessage(event.message, completedAt);
      thinkingCompleted = true;
      stopItemTimer();
      const cursorLabel = createThinkingCursorLabel(event.message, patch.options.mode);
      const holdMs =
        cursorLabel !== DEFAULT_THINKING_CURSOR_LABEL && summaryFirstVisibleAt !== undefined
          ? remainingSummaryCursorMs(summaryFirstVisibleAt, completedAt)
          : 0;
      if (holdMs > 0) {
        holdingSummaryCursor = true;
        renderThinkingCursor(ctx, completedAt);
        summaryHoldTimer = setTimeout(() => showResponding(ctx), holdMs);
      } else {
        showResponding(ctx);
      }
    }

    if (
      !sawThinkingInCurrentMessage &&
      ctx.model?.reasoning &&
      (event.assistantMessageEvent.type === "text_start" ||
        event.assistantMessageEvent.type === "text_delta")
    ) {
      showResponding(ctx);
    }
  });

  const clearStreamState = (ctx: ExtensionContext) => {
    clearSummaryHold();
    stopItemTimer();
    thinkingStartedAt = undefined;
    summaryFirstVisibleAt = undefined;
    lastWorkingMessage = undefined;
    if (ctx.mode !== "tui") return;
    ctx.ui.setWorkingMessage();
  };

  pi.on("message_end", (event, ctx) => {
    if (event.message.role !== "assistant") return;
    if (patch && sawThinkingInCurrentMessage && !thinkingCompleted) {
      patch.completeMessage(event.message);
    }
    currentAssistant = undefined;
    clearStreamState(ctx);
  });

  pi.on("agent_end", (_event, ctx) => {
    if (patch && currentAssistant && sawThinkingInCurrentMessage && !thinkingCompleted) {
      patch.completeMessage(currentAssistant);
    }
    currentAssistant = undefined;
    clearStreamState(ctx);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    stopItemTimer();
    removeInputListener?.();
    removeInputListener = undefined;
    if (ctx.hasUI) {
      ctx.ui.setWorkingMessage();
    }
    patch?.dispose();
    patch = undefined;
  });
}

export {
  BUILT_IN_MODEL_BEHAVIORS,
  loadBuiltInModelBehaviors,
  parseModelBehaviorConfig,
  resolveConfiguredThinkingBehavior,
  type ConfiguredThinkingBehavior,
  type ModelBehaviorConfig,
  type ModelBehaviorRule,
  type ModelIdentity,
} from "./model-behaviors.ts";
export {
  configToRenderOptions,
  DEFAULT_THINKING_FOLD_CONFIG,
  getThinkingFoldConfigPath,
  loadThinkingFoldConfig,
  normalizeThinkingFoldConfig,
  saveThinkingFoldConfig,
  THINKING_FOLD_SETTINGS_NAMESPACE,
  type ThinkingFoldConfig,
} from "./config.ts";
export {
  createThinkingCursorLabel,
  createThinkingDisplayMessage,
  DEFAULT_THINKING_CURSOR_LABEL,
  DEFAULT_THINKING_FOLD_OPTIONS,
  extractLatestSummaryHeadline,
  formatStreamingThinkingSeconds,
  formatThinkingSeconds,
  installThinkingFoldPatch,
  resolveThinkingBehavior,
  resolveThinkingDisplayBehavior,
  type ThinkingCompletedBehavior,
  type ThinkingDisplayState,
  type ThinkingFoldMode,
  type ThinkingFoldOptions,
  type ThinkingStreamingBehavior,
  type ThinkingFoldPatchHandle,
  type ThinkingTiming,
} from "./renderer.ts";
