import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export type ConfiguredThinkingBehavior = "trace" | "summary";

export interface ModelBehaviorRule {
  id?: string;
  api?: string;
  provider?: string;
  model?: string;
  behavior: ConfiguredThinkingBehavior;
}

export interface ModelBehaviorConfig {
  version: 1;
  rules: ModelBehaviorRule[];
}

export interface ModelIdentity {
  api: string;
  provider: string;
  model: string;
}

const BUILT_IN_CONFIG_PATH = fileURLToPath(new URL("./model-behaviors.json", import.meta.url));

function optionalPattern(value: unknown, field: string, index: number): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`model-behaviors rule ${index} has invalid ${field}`);
  }
  const pattern = value.trim();
  try {
    new RegExp(pattern, "i");
  } catch (error) {
    throw new Error(
      `model-behaviors rule ${index} has invalid ${field} regex: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  return pattern;
}

export function parseModelBehaviorConfig(value: unknown): ModelBehaviorConfig {
  if (!value || typeof value !== "object") throw new Error("model-behaviors must be an object");
  const input = value as { version?: unknown; rules?: unknown };
  if (input.version !== 1) throw new Error("model-behaviors version must be 1");
  if (!Array.isArray(input.rules)) throw new Error("model-behaviors rules must be an array");

  const rules = input.rules.map((value, index): ModelBehaviorRule => {
    if (!value || typeof value !== "object") {
      throw new Error(`model-behaviors rule ${index} must be an object`);
    }
    const rule = value as Record<string, unknown>;
    const api = optionalPattern(rule.api, "api", index);
    const provider = optionalPattern(rule.provider, "provider", index);
    const model = optionalPattern(rule.model, "model", index);
    if (!api && !provider && !model) {
      throw new Error(`model-behaviors rule ${index} needs api, provider, or model`);
    }
    if (rule.behavior !== "trace" && rule.behavior !== "summary") {
      throw new Error(`model-behaviors rule ${index} has invalid behavior`);
    }
    if (rule.id !== undefined && (typeof rule.id !== "string" || !rule.id.trim())) {
      throw new Error(`model-behaviors rule ${index} has invalid id`);
    }
    return {
      ...(typeof rule.id === "string" ? { id: rule.id.trim() } : {}),
      ...(api ? { api } : {}),
      ...(provider ? { provider } : {}),
      ...(model ? { model } : {}),
      behavior: rule.behavior,
    };
  });

  return { version: 1, rules };
}

function regexMatches(pattern: string, value: string): boolean {
  return new RegExp(pattern, "i").test(value);
}

function specificity(rule: ModelBehaviorRule): number {
  const selectorCount = [rule.api, rule.provider, rule.model].filter(
    (pattern) => pattern !== undefined,
  ).length;
  return (
    selectorCount * 100 +
    (rule.model ? 4 : 0) +
    (rule.provider ? 2 : 0) +
    (rule.api ? 1 : 0)
  );
}

export function resolveConfiguredThinkingBehavior(
  identity: ModelIdentity,
  config: ModelBehaviorConfig = BUILT_IN_MODEL_BEHAVIORS,
): ConfiguredThinkingBehavior | undefined {
  let selected: { behavior: ConfiguredThinkingBehavior; score: number; index: number } | undefined;

  config.rules.forEach((rule, index) => {
    if (rule.api && !regexMatches(rule.api, identity.api)) return;
    if (rule.provider && !regexMatches(rule.provider, identity.provider)) return;
    if (rule.model && !regexMatches(rule.model, identity.model)) return;
    const score = specificity(rule);
    if (!selected || score > selected.score || (score === selected.score && index > selected.index)) {
      selected = { behavior: rule.behavior, score, index };
    }
  });

  return selected?.behavior;
}

export function loadBuiltInModelBehaviors(path = BUILT_IN_CONFIG_PATH): ModelBehaviorConfig {
  return parseModelBehaviorConfig(JSON.parse(readFileSync(path, "utf8")));
}

export const BUILT_IN_MODEL_BEHAVIORS = loadBuiltInModelBehaviors();
