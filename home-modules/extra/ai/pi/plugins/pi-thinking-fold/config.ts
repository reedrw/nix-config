import {
  getSharedSettingsPath,
  readSettingsNamespace,
  writeSettingsNamespace,
} from "./shared-settings/index.ts";
import {
  DEFAULT_THINKING_FOLD_OPTIONS,
  type ThinkingCompletedBehavior,
  type ThinkingFoldOptions,
  type ThinkingStreamingBehavior,
} from "./renderer.ts";

export interface ThinkingFoldConfig {
  foldThreshold: number;
  streamingBehavior: ThinkingStreamingBehavior;
  completedBehavior: ThinkingCompletedBehavior;
}

export const DEFAULT_THINKING_FOLD_CONFIG: ThinkingFoldConfig = {
  foldThreshold: DEFAULT_THINKING_FOLD_OPTIONS.previewLines,
  streamingBehavior: DEFAULT_THINKING_FOLD_OPTIONS.streamingBehavior,
  completedBehavior: DEFAULT_THINKING_FOLD_OPTIONS.completedBehavior,
};

export const THINKING_FOLD_SETTINGS_NAMESPACE = "thinking-fold";

export function getThinkingFoldConfigPath(): string {
  return getSharedSettingsPath();
}

function isFoldThreshold(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 1 && value <= 20;
}

function isStreamingBehavior(value: unknown): value is ThinkingStreamingBehavior {
  return value === "auto" || value === "preview" || value === "collapse";
}

function isCompletedBehavior(value: unknown): value is ThinkingCompletedBehavior {
  return value === "auto" || value === "collapse" || value === "preview" || value === "full";
}

export function normalizeThinkingFoldConfig(value: unknown): ThinkingFoldConfig {
  if (!value || typeof value !== "object") return { ...DEFAULT_THINKING_FOLD_CONFIG };
  const input = value as {
    foldThreshold?: unknown;
    previewLines?: unknown;
    streamingBehavior?: unknown;
    completedBehavior?: unknown;
    autoCollapse?: unknown;
  };

  return {
    // previewLines and autoCollapse are legacy settings. Preserve their visible
    // behavior when migrating an existing user configuration.
    foldThreshold: isFoldThreshold(input.foldThreshold)
      ? input.foldThreshold
      : isFoldThreshold(input.previewLines)
        ? input.previewLines
        : DEFAULT_THINKING_FOLD_CONFIG.foldThreshold,
    streamingBehavior: isStreamingBehavior(input.streamingBehavior)
      ? input.streamingBehavior
      : DEFAULT_THINKING_FOLD_CONFIG.streamingBehavior,
    completedBehavior: isCompletedBehavior(input.completedBehavior)
      ? input.completedBehavior
      : input.autoCollapse === false
        ? "preview"
        : input.autoCollapse === true
          ? "collapse"
          : DEFAULT_THINKING_FOLD_CONFIG.completedBehavior,
  };
}

export function loadThinkingFoldConfig(path = getThinkingFoldConfigPath()): ThinkingFoldConfig {
  return readSettingsNamespace(THINKING_FOLD_SETTINGS_NAMESPACE, normalizeThinkingFoldConfig, path);
}

export function saveThinkingFoldConfig(
  config: ThinkingFoldConfig,
  path = getThinkingFoldConfigPath(),
): void {
  writeSettingsNamespace(
    THINKING_FOLD_SETTINGS_NAMESPACE,
    normalizeThinkingFoldConfig(config),
    path,
  );
}

export function configToRenderOptions(
  config: ThinkingFoldConfig,
): Pick<
  ThinkingFoldOptions,
  "previewLines" | "streamingBehavior" | "completedBehavior"
> {
  return {
    previewLines: config.foldThreshold,
    streamingBehavior: config.streamingBehavior,
    completedBehavior: config.completedBehavior,
  };
}
