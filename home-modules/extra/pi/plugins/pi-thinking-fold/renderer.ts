import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import {
  AssistantMessageComponent,
  ToolExecutionComponent,
  truncateToVisualLines,
} from "@earendil-works/pi-coding-agent";
import {
  Markdown,
  Spacer,
  Text,
  type Component,
  type DefaultTextStyle,
  type MarkdownOptions,
  type MarkdownTheme,
} from "@earendil-works/pi-tui";
import { resolveConfiguredThinkingBehavior } from "./model-behaviors.ts";

export type ThinkingFoldMode = "auto" | "trace" | "summary";
export type ThinkingStreamingBehavior = "auto" | "preview" | "collapse";
export type ThinkingCompletedBehavior = "auto" | "collapse" | "preview" | "full";
type EffectiveThinkingDisplayBehavior = Exclude<ThinkingCompletedBehavior, "auto">;

export interface ThinkingFoldOptions {
  mode: ThinkingFoldMode;
  previewLines: number;
  streamingBehavior: ThinkingStreamingBehavior;
  completedBehavior: ThinkingCompletedBehavior;
  /** @deprecated Use completedBehavior instead. */
  autoCollapse?: boolean;
  toggleKey: string;
}

export interface ThinkingTiming {
  startedAt: number;
  completedAt?: number;
}

export interface ThinkingDisplayState {
  timing?: ThinkingTiming;
  now?: number;
}

export const DEFAULT_THINKING_CURSOR_LABEL = "Thinking...";

export const DEFAULT_THINKING_FOLD_OPTIONS: ThinkingFoldOptions = {
  mode: "auto",
  previewLines: 5,
  streamingBehavior: "auto",
  completedBehavior: "auto",
  toggleKey: "ctrl+t",
};

interface ComponentState {
  fullMessage?: AssistantMessage;
  renderedMessage?: AssistantMessage;
}

interface AssistantMessageInternals {
  contentContainer?: { children?: Component[] };
  hideThinkingBlock?: boolean;
  hiddenThinkingLabel?: string;
}

interface MarkdownInternals {
  text?: string;
  paddingX?: number;
  paddingY?: number;
  defaultTextStyle?: DefaultTextStyle;
  theme?: MarkdownTheme;
  options?: MarkdownOptions;
}

interface PatchRecord {
  owners: number;
  expanded: boolean;
  now: number;
  options: ThinkingFoldOptions;
  originalUpdate: AssistantMessageComponent["updateContent"];
  states: WeakMap<AssistantMessageComponent, ComponentState>;
  components: Set<WeakRef<AssistantMessageComponent>>;
  knownComponents: WeakSet<AssistantMessageComponent>;
  timings: Map<number, ThinkingTiming>;
  updateOptions(options: Partial<ThinkingFoldOptions>): void;
  setExpanded(expanded: boolean): void;
  setMessageTiming(timestamp: number, timing: ThinkingTiming): void;
  beginMessage(message: AssistantMessage, startedAt?: number): void;
  completeMessage(message: AssistantMessage, completedAt?: number): void;
  tick(now?: number): void;
  rerenderAll(): void;
  rerenderTimestamp(timestamp: number): void;
}

export interface ThinkingFoldPatchHandle {
  readonly expanded: boolean;
  readonly options: ThinkingFoldOptions;
  updateOptions(options: Partial<ThinkingFoldOptions>): void;
  setExpanded(expanded: boolean): void;
  toggle(): void;
  setMessageTiming(timestamp: number, timing: ThinkingTiming): void;
  beginMessage(message: AssistantMessage, startedAt?: number): void;
  completeMessage(message: AssistantMessage, completedAt?: number): void;
  tick(now?: number): void;
  dispose(): void;
}

const PATCH_SYMBOL = Symbol.for("@99percentpeople/pi-thinking-fold/assistant-message-patch");

function normalizedOptions(options: Partial<ThinkingFoldOptions>): ThinkingFoldOptions {
  const previewLines = options.previewLines ?? DEFAULT_THINKING_FOLD_OPTIONS.previewLines;
  const completedBehavior =
    options.completedBehavior === "auto" ||
    options.completedBehavior === "collapse" ||
    options.completedBehavior === "preview" ||
    options.completedBehavior === "full"
      ? options.completedBehavior
      : options.autoCollapse === false
        ? "preview"
        : options.autoCollapse === true
          ? "collapse"
          : DEFAULT_THINKING_FOLD_OPTIONS.completedBehavior;
  return {
    mode: options.mode ?? DEFAULT_THINKING_FOLD_OPTIONS.mode,
    previewLines:
      Number.isInteger(previewLines) && previewLines > 0
        ? previewLines
        : DEFAULT_THINKING_FOLD_OPTIONS.previewLines,
    streamingBehavior:
      options.streamingBehavior === "auto" ||
      options.streamingBehavior === "collapse" ||
      options.streamingBehavior === "preview"
        ? options.streamingBehavior
        : DEFAULT_THINKING_FOLD_OPTIONS.streamingBehavior,
    completedBehavior,
    toggleKey: options.toggleKey?.trim() || DEFAULT_THINKING_FOLD_OPTIONS.toggleKey,
  };
}

function cleanSummaryHeadline(value: string): string {
  const cleaned = value
    .replace(/^\s{0,3}#{1,6}\s+/, "")
    .replace(/^\s*[-*+]\s+/, "")
    .replace(/^\*\*(.*?)\*\*$/, "$1")
    .replace(/^__(.*?)__$/, "$1")
    .replace(/^\*\*/, "")
    .replace(/\*\*$/, "")
    .replace(/\s+/g, " ")
    .trim();
  return Array.from(cleaned).length > 96
    ? `${Array.from(cleaned).slice(0, 95).join("")}…`
    : cleaned;
}

function latestSummaryHeadlineFromText(text: string): string | undefined {
  const boldHeadings = [...text.matchAll(/^\s*\*\*(.+?)\*\*\s*$/gm)];
  const boldHeadline = boldHeadings.at(-1)?.[1];
  if (boldHeadline?.trim()) return cleanSummaryHeadline(boldHeadline);

  const latestParagraph = text
    .trim()
    .split(/\n\s*\n/)
    .filter((paragraph) => paragraph.trim())
    .at(-1);
  const latestLine = latestParagraph
    ?.split("\n")
    .map((line) => line.trim())
    .find(Boolean);
  const headline = latestLine ? cleanSummaryHeadline(latestLine) : "";
  return headline || undefined;
}

export function extractLatestSummaryHeadline(message: AssistantMessage): string | undefined {
  for (let index = message.content.length - 1; index >= 0; index -= 1) {
    const block = message.content[index];
    if (block?.type !== "thinking" || !block.thinking.trim()) continue;
    return latestSummaryHeadlineFromText(block.thinking);
  }
  return undefined;
}

export function resolveThinkingBehavior(
  message: AssistantMessage,
  mode: ThinkingFoldMode,
): Exclude<ThinkingFoldMode, "auto"> {
  if (mode !== "auto") return mode;

  return resolveConfiguredThinkingBehavior(message) ?? "trace";
}

export function resolveThinkingDisplayBehavior(
  message: AssistantMessage,
  options: Pick<
    ThinkingFoldOptions,
    "mode" | "streamingBehavior" | "completedBehavior"
  >,
  completed: boolean,
): EffectiveThinkingDisplayBehavior {
  if (completed) {
    return options.completedBehavior === "auto" ? "collapse" : options.completedBehavior;
  }
  if (options.streamingBehavior !== "auto") return options.streamingBehavior;
  return resolveThinkingBehavior(message, options.mode) === "summary" ? "collapse" : "preview";
}

export function formatThinkingSeconds(milliseconds: number): string {
  return `${(Math.max(0, milliseconds) / 1000).toFixed(1)}s`;
}

export function formatStreamingThinkingSeconds(milliseconds: number): string {
  // Same m/s shape as the batch header's formatThought ("1m 30s", not "90s")
  // — whole-second precision, since this label only ticks per second of
  // streaming; formatThought's 0.1s precision is for the animated header.
  const s = Math.floor(Math.max(0, milliseconds) / 1000);
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m ${s % 60}s`;
}

export function createThinkingCursorLabel(
  message: AssistantMessage,
  mode: ThinkingFoldMode,
): string {
  const headline =
    resolveThinkingBehavior(message, mode) === "summary"
      ? extractLatestSummaryHeadline(message)
      : undefined;
  return headline ?? DEFAULT_THINKING_CURSOR_LABEL;
}

// ── custom-ui unification ─────────────────────────
//
// custom-ui (extensions/lib/custom-ui.ts) publishes an animation API on
// globalThis. With it present, exactly ONE animated "Thinking" indicator
// exists: the tool-batch header while a batch is open (this package's
// streaming thinking row is suppressed then — its duration already counts
// into the header), otherwise THIS row, animated through the shared API
// (dots spinner + shimmer verb, colors from the terminal's base16 palette).
// Without the API, behavior is unchanged (static label, own row always).
interface CustomUiAnimApi {
  frame: number;
  batchOpen: boolean;
  requestRender?(): void;
  tick(): number;
  completedLabel(seconds: string, canExpand: boolean, expandSuffix: string): string;
  streamingLabel(
    seconds: string,
    canExpand: boolean,
    expandSuffix: string,
    seed: number,
  ): string;
}

export function customUiAnim(): CustomUiAnimApi | undefined {
  return (globalThis as Record<string, unknown>).__piCustomUiAnim as
    | CustomUiAnimApi
    | undefined;
}

function foldThinkingText(
  text: string,
  previewLines: number,
  width: number,
  outputPad: number,
): string {
  const availableWidth = Math.max(10, width - outputPad * 2);
  const stableText = text
    .replace(/\r\n|\r/g, "\n")
    .replace(/\t/g, "   ")
    .replace(/\n+$/, "");
  const result = truncateToVisualLines(stableText, previewLines, availableWidth);
  return result.visualLines.map((line) => line.trimEnd()).join("\n").replace(/\n+$/, "");
}

function hasFoldedThinkingContent(
  message: AssistantMessage,
  previewLines: number,
  width: number,
  outputPad: number,
): boolean {
  const availableWidth = Math.max(10, width - outputPad * 2);
  return message.content.some(
    (block) =>
      block.type === "thinking" &&
      truncateToVisualLines(block.thinking, previewLines, availableWidth).skippedCount > 0,
  );
}

interface NativeThinkingRun {
  start: number;
  end: number;
  text: string;
}

interface MarkedThinkingSection {
  marker: string;
  text: string;
  showLabel: boolean;
}

interface MarkedThinkingMessage {
  message: AssistantMessage;
  sections: MarkedThinkingSection[];
}

/**
 * Shared render state for all thinking sections in one assistant message.
 * Every section is rendered first; only then do we decide whether content is
 * actually hidden and whether the expansion hint belongs in the header.
 */
class RenderedThinkingContext {
  readonly sections: RenderedThinkingSection[] = [];
  canExpand = false;
  private preparedWidth?: number;

  constructor(
    readonly behavior: EffectiveThinkingDisplayBehavior,
    readonly previewLines: number,
    readonly collapseCanExpand: boolean,
    readonly labelFor: (canExpand: boolean) => string,
  ) {}

  add(section: RenderedThinkingSection): void {
    this.sections.push(section);
  }

  prepare(width: number): void {
    if (this.preparedWidth === width) return;
    for (const section of this.sections) section.prepare(width);
    this.canExpand =
      this.behavior === "collapse"
        ? this.collapseCanExpand
        : this.behavior === "preview"
          ? this.sections.some((section) => section.renderedLineCount > this.previewLines)
          : false;
    this.preparedWidth = width;
  }

  invalidate(): void {
    this.preparedWidth = undefined;
  }
}

/** Render Pi's native Markdown first, then retain its final terminal rows. */
class RenderedThinkingSection implements Component {
  private fullLines: string[] = [];
  private preparedWidth?: number;
  private labelText?: string;

  constructor(
    private readonly content: Markdown,
    // Markdown for the native label; Text when the custom-ui animation API
    // supplies the label (raw SGR must not go through Markdown rendering).
    private readonly label: Markdown | Text | undefined,
    private readonly context: RenderedThinkingContext,
  ) {
    context.add(this);
  }

  get renderedLineCount(): number {
    return this.fullLines.length;
  }

  prepare(width: number): void {
    if (this.preparedWidth === width) return;
    this.fullLines = this.content.render(width);
    this.preparedWidth = width;
  }

  render(width: number): string[] {
    this.context.prepare(width);
    const contentLines =
      this.context.behavior === "collapse"
        ? []
        : this.context.behavior === "preview"
          ? this.fullLines.slice(-this.context.previewLines)
          : this.fullLines;
    if (!this.label) return contentLines;

    const labelText = this.context.labelFor(this.context.canExpand);
    if (labelText !== this.labelText) {
      this.label.setText(labelText);
      this.labelText = labelText;
    }
    if (labelText === "") {
      // Label suppressed (batch spinner owns the animation): keep one blank
      // line between the batch block and the reasoning preview — healthy
      // separation instead of the preview hugging the glance rows.
      return ["", ...contentLines];
    }
    return [...this.label.render(width), ...contentLines];
  }

  invalidate(): void {
    this.content.invalidate();
    this.label?.invalidate();
    this.preparedWidth = undefined;
    this.context.invalidate();
  }
}

function collectThinkingRuns(message: AssistantMessage): NativeThinkingRun[] {
  const runs: NativeThinkingRun[] = [];
  let index = 0;
  while (index < message.content.length) {
    const block = message.content[index];
    if (!block || block.type !== "thinking") {
      index++;
      continue;
    }

    const start = index;
    const fragments: string[] = [];
    while (index < message.content.length) {
      const thinkingBlock = message.content[index];
      if (!thinkingBlock || thinkingBlock.type !== "thinking") break;
      const text = thinkingBlock.thinking.trim();
      if (text) fragments.push(text);
      index++;
    }
    runs.push({ start, end: index, text: fragments.join("\n\n") });
  }
  return runs;
}

function createMarkedThinkingMessage(
  message: AssistantMessage,
  behavior: EffectiveThinkingDisplayBehavior,
): MarkedThinkingMessage | undefined {
  const runs = collectThinkingRuns(message);
  const firstRun = runs[0];
  if (!firstRun) return undefined;

  const content = [...message.content];
  const sections: MarkedThinkingSection[] = [];
  const clearRun = (run: NativeThinkingRun) => {
    for (let index = run.start; index < run.end; index++) {
      const block = content[index];
      if (block?.type === "thinking") content[index] = { ...block, thinking: "" };
    }
  };
  const markRun = (run: NativeThinkingRun, runIndex: number, showLabel: boolean) => {
    clearRun(run);
    const block = content[run.start];
    if (!block || block.type !== "thinking") return;
    const marker = `\uE000thinking-fold:${message.timestamp}:${runIndex}\uE001`;
    content[run.start] = { ...block, thinking: marker };
    sections.push({ marker, text: run.text, showLabel });
  };

  if (behavior === "collapse") {
    for (const run of runs) clearRun(run);
    markRun(firstRun, 0, true);
  } else if (behavior === "preview") {
    for (const run of runs) clearRun(run);
    runs.forEach((run, runIndex) => {
      if (runIndex === 0 || run.text) markRun(run, runIndex, runIndex === 0);
    });
  } else {
    markRun(firstRun, 0, true);
  }

  return { message: { ...message, content }, sections };
}

function getMarkdownInternals(component: Component): MarkdownInternals | undefined {
  if (!(component instanceof Markdown)) return undefined;
  const internals = component as unknown as MarkdownInternals;
  return typeof internals.text === "string" &&
    typeof internals.paddingX === "number" &&
    typeof internals.paddingY === "number" &&
    internals.theme
    ? internals
    : undefined;
}

function cloneNativeMarkdown(component: Component, text: string): Markdown | undefined {
  const internals = getMarkdownInternals(component);
  if (!internals?.theme || internals.paddingX === undefined || internals.paddingY === undefined) {
    return undefined;
  }
  return new Markdown(
    text,
    internals.paddingX,
    internals.paddingY,
    internals.theme,
    internals.defaultTextStyle,
    internals.options,
  );
}

function replaceMarkedThinkingSections(
  component: AssistantMessageComponent,
  marked: MarkedThinkingMessage,
  behavior: EffectiveThinkingDisplayBehavior,
  previewLines: number,
  collapseCanExpand: boolean,
  labelFor: (canExpand: boolean) => string,
): boolean {
  const internals = component as unknown as AssistantMessageInternals;
  const children = internals.contentContainer?.children;
  if (!children) return false;

  const pending = new Map(marked.sections.map((section) => [section.marker, section]));
  const context = new RenderedThinkingContext(
    behavior,
    previewLines,
    collapseCanExpand,
    labelFor,
  );
  for (let index = 0; index < children.length; index++) {
    const child = children[index];
    if (!child) continue;
    const markdown = getMarkdownInternals(child);
    const section = markdown?.text ? pending.get(markdown.text) : undefined;
    if (!section) continue;

    const content = cloneNativeMarkdown(child, section.text);
    // The animated label carries raw SGR (spinner + shimmer) that Markdown
    // rendering would mangle — when the custom-ui animation API is present,
    // render the label through a plain Text instead (same setText/render
    // interface RenderedThinkingSection needs). Without the API the native
    // Markdown label is kept byte-for-byte.
    const label = section.showLabel
      ? customUiAnim()
        ? new Text("")
        : cloneNativeMarkdown(child, "")
      : undefined;
    if (!content || (section.showLabel && !label)) return false;
    children[index] = new RenderedThinkingSection(content, label, context);
    pending.delete(section.marker);
  }
  return pending.size === 0;
}

function createStreamingThinkingLabel(
  options: ThinkingFoldOptions,
  timing: ThinkingTiming | undefined,
  now: number,
  canExpand: boolean,
): string {
  const duration = timing ? formatThinkingSeconds(now - timing.startedAt) : "0.0s";
  return `Thinking ${duration}${canExpand ? `  (${options.toggleKey} to expand)` : ""}`;
}

function createCompletedThinkingLabel(
  options: ThinkingFoldOptions,
  timing: ThinkingTiming,
  canExpand: boolean,
): string {
  const duration = formatThinkingSeconds(timing.completedAt! - timing.startedAt);
  return `Thought for ${duration}${canExpand ? `  (${options.toggleKey} to expand)` : ""}`;
}

/**
 * @deprecated Preview folding now happens after native Markdown rendering and
 * cannot be represented faithfully as an AssistantMessage. Use
 * installThinkingFoldPatch() for the TUI behavior; this source-level helper is
 * retained for compatibility with existing consumers.
 */
export function createThinkingDisplayMessage(
  message: AssistantMessage,
  options: ThinkingFoldOptions,
  expanded: boolean,
  width: number,
  outputPad = 1,
  display: ThinkingDisplayState = {},
): AssistantMessage {
  if (expanded) return message;

  const firstThinkingIndex = message.content.findIndex((block) => block.type === "thinking");
  if (firstThinkingIndex === -1) return message;

  const timing = display.timing;
  const completed = timing?.completedAt !== undefined;
  const displayBehavior = resolveThinkingDisplayBehavior(message, options, completed);
  const hasThinkingContent = message.content.some(
    (block) => block.type === "thinking" && block.thinking.trim(),
  );
  const canExpand =
    displayBehavior === "collapse"
      ? hasThinkingContent
      : displayBehavior === "preview" &&
        hasFoldedThinkingContent(message, options.previewLines, width, outputPad);
  const label =
    completed && timing
      ? createCompletedThinkingLabel(options, timing, canExpand)
      : createStreamingThinkingLabel(options, timing, display.now ?? Date.now(), canExpand);
  let changed = false;
  const content = message.content.map((block, index) => {
    if (block.type !== "thinking") return block;

    const visibleThinking =
      displayBehavior === "collapse"
        ? ""
        : displayBehavior === "preview"
          ? foldThinkingText(block.thinking, options.previewLines, width, outputPad)
          : block.thinking;
    const thinking =
      index === firstThinkingIndex
        ? visibleThinking
          ? `${label}\n${visibleThinking}`
          : label
        : visibleThinking;

    if (thinking === block.thinking) return block;
    changed = true;
    return { ...block, thinking };
  });

  return changed ? { ...message, content } : message;
}

function getPatchRecord(): PatchRecord | undefined {
  return (AssistantMessageComponent.prototype as unknown as Record<PropertyKey, unknown>)[
    PATCH_SYMBOL
  ] as PatchRecord | undefined;
}

// Mirror completed thinking durations for the custom-ui extensions
// (extensions/lib/custom-ui.ts): they fold the duration into their tool
// batch header ("✻ Thought for 3.5s · Ran 2 tool calls") and need the same
// timings this package reconstructs for restored sessions.
const THOUGHT_FOR_KEY = "__piCustomUiThoughtFor";

function publishThoughtFor(timestamp: number, timing: ThinkingTiming): void {
  if (timing.completedAt === undefined) return;
  const w = globalThis as Record<string, unknown>;
  const map = (w[THOUGHT_FOR_KEY] ??= new Map()) as Map<number, number>;
  map.set(timestamp, Math.max(0, timing.completedAt - timing.startedAt));
}

// Raw timings (startedAt + optional completedAt) so the custom-ui header
// can count an in-progress reasoning block up in real time.
const THOUGHT_LIVE_KEY = "__piCustomUiThoughtLive";

function publishThoughtLive(timestamp: number, timing: ThinkingTiming): void {
  const w = globalThis as Record<string, unknown>;
  const map = (w[THOUGHT_LIVE_KEY] ??= new Map()) as Map<number, ThinkingTiming>;
  map.set(timestamp, { startedAt: timing.startedAt, completedAt: timing.completedAt });
}

// True when the custom-ui UI owns tool rendering: assistant messages that
// carry tool calls then get their thinking folded into the tool batch header
// instead of spending a line repeating the duration here.
function customUiMergeEnabled(): boolean {
  for (const path of [join(process.cwd(), ".pi", "settings.json"), join(homedir(), ".pi", "agent", "settings.json")]) {
    try {
      const settings = JSON.parse(readFileSync(path, "utf8")) as { customUi?: unknown };
      if (typeof settings.customUi === "boolean") return settings.customUi;
    } catch {
      // Missing or unparsable — fall through to the next scope.
    }
  }
  return true;
}

const TOOL_EXPAND_KEY = "__piCustomUiToolExpand";

function isToolExpandAll(): boolean {
  return (globalThis as Record<string, unknown>)[TOOL_EXPAND_KEY] === true;
}

function setToolExpandAll(expanded: boolean): void {
  const w = globalThis as Record<string, unknown>;
  if (w[TOOL_EXPAND_KEY] === expanded) return;
  w[TOOL_EXPAND_KEY] = expanded;
  // Expansion is a global toggle: re-decide every message's thinking display.
  getPatchRecord()?.rerenderAll();
}

// Pi pushes the global ctrl+o toggle through ToolExecutionComponent#setExpanded
// for every tool row. Observe it there so ctrl+o can also expand the thinking
// folded into the custom-ui batch headers.
const TOOL_EXPAND_PATCHED = Symbol.for("pi-thinking-fold/tool-expand-patch");

function patchToolExpansion(): () => void {
  const prototype = ToolExecutionComponent.prototype as unknown as Record<PropertyKey, unknown>;
  if (typeof prototype.setExpanded !== "function" || prototype[TOOL_EXPAND_PATCHED]) {
    return () => {};
  }
  prototype[TOOL_EXPAND_PATCHED] = true;
  const originalSetExpanded = prototype.setExpanded as (this: ToolExecutionComponent, expanded: boolean) => void;
  prototype.setExpanded = function (expanded: boolean) {
    setToolExpandAll(expanded);
    originalSetExpanded.call(this, expanded);
  };
  return () => {
    prototype.setExpanded = originalSetExpanded;
    delete prototype[TOOL_EXPAND_PATCHED];
  };
}

function setPatchRecord(record: PatchRecord | undefined): void {
  const prototype = AssistantMessageComponent.prototype as unknown as Record<PropertyKey, unknown>;
  if (record) prototype[PATCH_SYMBOL] = record;
  else delete prototype[PATCH_SYMBOL];
}

function rebuild(
  component: AssistantMessageComponent,
  state: ComponentState,
  record: PatchRecord,
): void {
  const message = state.fullMessage;
  if (!message) return;

  const internals = component as unknown as AssistantMessageInternals;
  const nativeHidden = internals.hideThinkingBlock;
  internals.hideThinkingBlock = false;
  try {
    if (record.expanded || isToolExpandAll() || !message.content.some((block) => block.type === "thinking")) {
      state.renderedMessage = message;
      record.originalUpdate.call(component, message);
      return;
    }

    const timing = record.timings.get(message.timestamp);
    const completed = timing?.completedAt !== undefined;
    // Claude-style merge: tool-call messages render no thinking line at all —
    // the batch header carries the duration. While a batch is open, a still-
    // streaming message's thinking is suppressed too (the animated batch
    // header counts its duration live via __piCustomUiThoughtLive; without
    // this, three "Thinking" indicators show at once: batch header, this
    // row, and pi's native loader). pi's hidden-thinking path with an empty
    // label renders zero lines. An explicit ctrl+t expand still wins.
    // Merge rule (completion only): pure thinking+toolCall messages fold
    // into the batch header. Narrated messages (thinking → text → toolCall)
    // keep their fold row — stripping a row that streamed visible text was
    // the missing-fold regression, and their duration must not double-count
    // in the header (custom-ui skips stamping narrated messages too).
    // STREAMING rows always render: while a batch is open the label is static
    // (the animated batch header owns the animation) but the content preview
    // stays visible; removing the old batchOpen suppression restored the
    // pre-unification behavior for post-tool thinking.
    const hasNarration = message.content.some(
      (block) => block.type === "text" && typeof block.text === "string" && block.text.trim().length > 0,
    );
    const mergeIntoHeader =
      !record.expanded &&
      !isToolExpandAll() &&
      customUiMergeEnabled() &&
      completed &&
      message.content.some((block) => block.type === "toolCall") &&
      !hasNarration;
    if (mergeIntoHeader) {
      // Strip thinking blocks from the display copy: pi's updateContent adds a
      // leading Spacer(1) for any message with visible content, and non-empty
      // thinking counts — leaving a blank line at every message boundary
      // inside the merged batch. With thinking gone, the component renders
      // zero lines and only the text blocks (if any) remain.
      const stripped = {
        ...message,
        content: message.content.filter((block) => block.type !== "thinking"),
      };
      state.renderedMessage = stripped;
      internals.hideThinkingBlock = true;
      internals.hiddenThinkingLabel = "";
      record.originalUpdate.call(component, stripped);
      return;
    }
    const behavior = resolveThinkingDisplayBehavior(message, record.options, completed);
    const marked = createMarkedThinkingMessage(message, behavior);
    if (!marked) {
      state.renderedMessage = message;
      record.originalUpdate.call(component, message);
      return;
    }

    const hasThinkingContent = message.content.some(
      (block) => block.type === "thinking" && block.thinking.trim(),
    );
    const labelFor = (canExpand: boolean) => {
      const api = customUiAnim();
      if (!completed && api) {
        // Animated streaming label from the shared custom-ui API —
        // dots spinner + shimmer verb, one clock with the batch header.
        const seconds = timing
          ? formatStreamingThinkingSeconds(record.now - timing.startedAt)
          : "0s";
        // While a batch is open the animated header owns the indicator —
        // suppress this row's label entirely and stream just the reasoning
        // preview beneath it. Fresh-thinking rows (no batch) get the full
        // animated label.
        if (api.batchOpen) return "";
        return api.streamingLabel(
          seconds,
          canExpand,
          `  (${record.options.toggleKey} to expand)`,
          message.timestamp,
        );
      }
      return completed && timing
        ? (api
          ? api.completedLabel(
              formatThinkingSeconds(timing.completedAt! - timing.startedAt),
              canExpand,
              `  (${record.options.toggleKey} to expand)`,
            )
          : createCompletedThinkingLabel(record.options, timing, canExpand))
        : createStreamingThinkingLabel(record.options, timing, record.now, canExpand);
    };

    state.renderedMessage = marked.message;
    record.originalUpdate.call(component, marked.message);
    const replaced = replaceMarkedThinkingSections(
      component,
      marked,
      behavior,
      record.options.previewLines,
      hasThinkingContent,
      labelFor,
    );
    if (!replaced) {
      // Pi changed its internal child layout. Never leak markers or damage the
      // message: fall back to the complete native rendering for this component.
      state.renderedMessage = message;
      record.originalUpdate.call(component, message);
    }
    tightenThinkingSpacing(component);
  } finally {
    internals.hideThinkingBlock = nativeHidden;
  }
}

function forEachLiveComponent(
  record: PatchRecord,
  callback: (component: AssistantMessageComponent, state: ComponentState) => void,
): void {
  for (const reference of record.components) {
    const component = reference.deref();
    if (!component) {
      record.components.delete(reference);
      continue;
    }
    const state = record.states.get(component);
    if (state) callback(component, state);
  }
}

function tightenThinkingSpacing(component: AssistantMessageComponent): void {
  // Pi surrounds thinking sections with Spacer(1) children (above any visible
  // content, below when text follows) — with the fold label present they read
  // as stray blank lines on both sides of the "Thought for" row. Drop the
  // spacers adjacent to replaced thinking sections.
  const children = (component as unknown as AssistantMessageInternals).contentContainer?.children;
  if (!children) return;
  for (let i = children.length - 1; i >= 0; i--) {
    if (!(children[i] instanceof RenderedThinkingSection)) continue;
    if (i + 1 < children.length && children[i + 1] instanceof Spacer) children.splice(i + 1, 1);
    if (i > 0 && children[i - 1] instanceof Spacer) children.splice(i - 1, 1);
  }
}

function createPatchRecord(options: Partial<ThinkingFoldOptions>): PatchRecord {
  const prototype = AssistantMessageComponent.prototype;
  const originalUpdate = prototype.updateContent;
  const record: PatchRecord = {
    owners: 0,
    expanded: false,
    now: Date.now(),
    options: normalizedOptions(options),
    originalUpdate,
    states: new WeakMap(),
    components: new Set(),
    knownComponents: new WeakSet(),
    timings: new Map(),
    updateOptions(next) {
      this.options = normalizedOptions({ ...this.options, ...next });
      this.rerenderAll();
    },
    setExpanded(expanded) {
      if (this.expanded === expanded) return;
      this.expanded = expanded;
      this.rerenderAll();
    },
    setMessageTiming(timestamp, timing) {
      this.timings.set(timestamp, { ...timing });
      publishThoughtFor(timestamp, timing);
      publishThoughtLive(timestamp, timing);
      this.rerenderTimestamp(timestamp);
    },
    beginMessage(message, startedAt = Date.now()) {
      this.timings.set(message.timestamp, { startedAt });
      publishThoughtLive(message.timestamp, { startedAt });
      this.now = startedAt;
      this.rerenderTimestamp(message.timestamp);
    },
    completeMessage(message, completedAt = Date.now()) {
      const timing = this.timings.get(message.timestamp) ?? {
        startedAt: Math.min(message.timestamp, completedAt),
      };
      if (timing.completedAt !== undefined) return;
      this.timings.set(message.timestamp, { ...timing, completedAt });
      publishThoughtFor(message.timestamp, { ...timing, completedAt });
      publishThoughtLive(message.timestamp, { ...timing, completedAt });
      this.now = completedAt;
      // Ctrl+T is a persistent global display preference. Auto-collapse only
      // controls the folded representation; completing a later turn must not
      // override an explicit expanded choice.
      this.rerenderTimestamp(message.timestamp);
    },
    tick(now = Date.now()) {
      this.now = now;
      forEachLiveComponent(this, (component, state) => {
        const timestamp = state.fullMessage?.timestamp;
        if (timestamp === undefined || this.timings.get(timestamp)?.completedAt !== undefined) return;
        rebuild(component, state, this);
      });
    },
    rerenderAll() {
      forEachLiveComponent(this, (component, state) => rebuild(component, state, this));
    },
    rerenderTimestamp(timestamp) {
      forEachLiveComponent(this, (component, state) => {
        if (state.fullMessage?.timestamp === timestamp) rebuild(component, state, this);
      });
    },
  };

  prototype.updateContent = function (message: AssistantMessage): void {
    const state = record.states.get(this) ?? {};

    // Container.invalidate() passes Pi's last display-only marker clone back
    // through updateContent(). Never mistake that clone for session source data.
    if (message !== state.renderedMessage) state.fullMessage = message;

    record.states.set(this, state);
    if (!record.knownComponents.has(this)) {
      record.knownComponents.add(this);
      record.components.add(new WeakRef(this));
    }
    rebuild(this, state, record);
  };

  setPatchRecord(record);
  return record;
}

export function installThinkingFoldPatch(
  options: Partial<ThinkingFoldOptions> = {},
): ThinkingFoldPatchHandle {
  const prototype = AssistantMessageComponent.prototype;
  if (typeof prototype.updateContent !== "function" || typeof prototype.render !== "function") {
    throw new Error("Pi's AssistantMessageComponent rendering API is unavailable");
  }

  const record = getPatchRecord() ?? createPatchRecord(options);
  record.owners += 1;
  record.updateOptions(options);
  let disposed = false;
  const restoreToolExpansion = patchToolExpansion();

  return {
    get expanded() {
      return record.expanded;
    },
    get options() {
      return { ...record.options };
    },
    updateOptions(next) {
      record.updateOptions(next);
    },
    setExpanded(expanded) {
      record.setExpanded(expanded);
    },
    toggle() {
      record.setExpanded(!record.expanded);
    },
    setMessageTiming(timestamp, timing) {
      record.setMessageTiming(timestamp, timing);
    },
    beginMessage(message, startedAt) {
      record.beginMessage(message, startedAt);
    },
    completeMessage(message, completedAt) {
      record.completeMessage(message, completedAt);
    },
    tick(now) {
      record.tick(now);
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      record.owners -= 1;
      if (record.owners > 0 || getPatchRecord() !== record) return;

      restoreToolExpansion();
      prototype.updateContent = record.originalUpdate;
      setPatchRecord(undefined);
    },
  };
}
