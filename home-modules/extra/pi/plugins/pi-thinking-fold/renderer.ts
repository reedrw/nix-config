import type { AssistantMessage } from "@earendil-works/pi-ai";
import {
  AssistantMessageComponent,
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
  visibleWidth,
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
  completedLabel(
    seconds: string,
    canExpand: boolean,
    expandSuffix: string,
    url?: string,
  ): string;
  streamingLabel(
    seconds: string,
    canExpand: boolean,
    expandSuffix: string,
    seed: number,
    url?: string,
  ): string;
}

export function customUiAnim(): CustomUiAnimApi | undefined {
  return (globalThis as Record<string, unknown>).__piCustomUiAnim as
    | CustomUiAnimApi
    | undefined;
}

// ── custom-ui tree channel ──────────────────────────────
//
// The custom-ui lib (extensions/lib/custom-ui.ts) owns the transcript tree:
// thinking rows are either depth-1 children of a batch (branch/anchor — the
// anchor hosts the batch header) or standalone top-level rows. The fork
// always renders thinking as rows; it consults branchScope(ts) for placement
// and visibility (headerOpen) per timestamp, and builds glyphs/labels
// through the shared helpers (no lib import — separate package).
type TreeBranchScope =
  | { kind: "standalone"; contentOpen: boolean }
  | {
      kind: "branch";
      batchIndex: number;
      last: boolean;
      headerOpen: boolean;
      contentOpen: boolean;
    }
  | {
      kind: "anchor";
      batchIndex: number;
      last: boolean;
      headerOpen: boolean;
      contentOpen: boolean;
      running: boolean;
      count: number;
    };

interface CustomUiTreeApi {
  branchScope(ts: number | undefined): TreeBranchScope;
  batchHeaderLine(batchIndex: number): string | undefined;
  linkWrap(text: string, url: string): string;
  thoughtGlyph(last: boolean): string;
  thoughtConnector(last: boolean): string;
  staticLabel(text: string): string;
  registerThoughtRow(timestamp: number, invalidate: () => void): void;
}

function customUiTree(): CustomUiTreeApi | undefined {
  return (globalThis as Record<string, unknown>).__piCustomUiTree as
    | CustomUiTreeApi
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
    // Content prefix for tree children: the through-connector `│  ` when
    // siblings follow, 3 spaces for the last child / standalone rows. Empty
    // when the tree channel is absent (native upstream look).
    readonly contentPrefix = "",
    readonly prefixWidth = 0,
    // The thought's toggle URL: expanded reasoning content carries the same
    // link as its label, so clicking the text itself collapses the node.
    readonly toggleUrl = "",
    // Last child of the batch: the branch row closes the tree, so it owns
    // the blank line that separates the tree from whatever follows (the
    // tool children get theirs from the next block's own spacing).
    readonly trailingBlank = false,
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
    // Content renders narrower than the row when a tree prefix will be
    // prepended — otherwise Markdown wraps long and the prefix overflows.
    this.fullLines = this.content.render(width - this.context.prefixWidth);
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
    const prefixed = this.context.contentPrefix
      ? contentLines.map((line) => this.context.contentPrefix + line)
      : contentLines;
    // Click-to-collapse on the body: per-line linkWrap keeps OSC 8 state
    // well-defined regardless of Markdown internals; blank lines stay bare.
    const tree = this.context.toggleUrl ? customUiTree() : undefined;
    const clickable = tree
      ? prefixed.map((line) => (line.trim() ? tree.linkWrap(line, this.context.toggleUrl) : line))
      : prefixed;
    if (!this.label) return this.context.trailingBlank ? [...clickable, ""] : clickable;

    // labelFor consults live lib state (tree channel, anim clock) — a throw
    // here would propagate through AssistantMessageComponent.render and kill
    // pi (message rendering is NOT a guarded tool render slot). Fall back to
    // a bare label instead.
    let labelText = "";
    try {
      labelText = this.context.labelFor(this.context.canExpand);
    } catch {
      labelText = "Thought";
    }
    if (labelText !== this.labelText) {
      this.label.setText(labelText);
      this.labelText = labelText;
    }
    const rows =
      labelText === ""
        ? // Label suppressed: keep one blank line between the block above
          // and the reasoning — healthy separation instead of hugging it.
          ["", ...clickable]
        : [...this.label.render(width), ...clickable];
    return this.context.trailingBlank ? [...rows, ""] : rows;
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
  contentPrefix = "",
  prefixWidth = 0,
  toggleUrl = "",
  trailingBlank = false,
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
    contentPrefix,
    prefixWidth,
    toggleUrl,
    trailingBlank,
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
        // paddingX/Y = 0: the tree grammar needs the glyph flush at the
        // header's column and NO blank lines around the label (Text's
        // defaults are 1/1 — the old flat look tolerated them, the tree
        // doesn't).
        ? new Text("", 0, 0)
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

// ── Tree-aware rebuild ──────────────────────────────

// Pi pushes the global ctrl+o toggle through ToolExecutionComponent#setExpanded.
// The tree walk that used to observe it here moved into the custom-ui lib
// (installToolExpandWalk): ctrl+o now expands/collapses every tree node.

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

  const tree = customUiTree();
  // Register this row's invalidator with the lib on every rebuild (first
  // render included) so tree state changes — anchor assignment, batch open/
  // close, glyph changes ╰─→├─, tick-driven header animation — can force a
  // re-render. invalidate() re-runs updateContent (patched → this rebuild).
  tree?.registerThoughtRow(message.timestamp, () => component.invalidate());

  const internals = component as unknown as AssistantMessageInternals;
  const nativeHidden = internals.hideThinkingBlock;
  internals.hideThinkingBlock = false;
  try {
    if (record.expanded || !message.content.some((block) => block.type === "thinking")) {
      // ctrl+t (explicit expand-all) or no thinking: native rendering.
      state.renderedMessage = message;
      record.originalUpdate.call(component, message);
      return;
    }

    const scope = tree
      ? tree.branchScope(message.timestamp)
      : ({ kind: "standalone", contentOpen: false } as TreeBranchScope);
    const timing = record.timings.get(message.timestamp);
    const completed = timing?.completedAt !== undefined;
    const inBranch = scope.kind !== "standalone";

    // Child of a closed batch header: hidden entirely — thinking renders at
    // its true chronological position whenever its ancestors are open, and
    // this ancestor is closed. Text blocks (if any) still render; the
    // stripped display copy keeps the component at zero thinking lines.
    // EXCEPTION: the anchor still hosts the COLLAPSED header line — a
    // collapsed header IS the row (§2.2), and for anchored batches the fork
    // is its only host (the first tool row doesn't carry it). Without this
    // the whole settled batch would render nothing at all.
    const anchorCollapsed = scope.kind === "anchor" && !scope.headerOpen;
    if (inBranch && !scope.headerOpen && !anchorCollapsed) {
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

    // Display behavior: streaming children show the preview beneath a
    // static branch label (the animated batch header owns the one-spinner
    // rule); completed children collapse by default and open per their
    // depth-3 flag (click / ctrl+o walk). Standalone rows keep the
    // configured behavior unless the user opened them.
    let behavior: EffectiveThinkingDisplayBehavior;
    if (anchorCollapsed) {
      // Collapsed anchored header: header line only — no branch label, no
      // content (the branch label and reasoning return when it opens).
      behavior = "collapse";
    } else if (!completed) {
      behavior = inBranch
        ? "preview"
        : resolveThinkingDisplayBehavior(message, record.options, false);
    } else if (inBranch) {
      behavior = scope.contentOpen ? "full" : "collapse";
    } else {
      behavior = scope.contentOpen
        ? "full"
        : resolveThinkingDisplayBehavior(message, record.options, true);
    }
    const marked = createMarkedThinkingMessage(message, behavior);
    if (!marked) {
      state.renderedMessage = message;
      record.originalUpdate.call(component, message);
      return;
    }

    const hasThinkingContent = message.content.some(
      (block) => block.type === "thinking" && block.thinking.trim(),
    );
    const url = `pi-action://node/thought/${message.timestamp}`;
    const glyph = inBranch && tree ? tree.thoughtGlyph(scope.last) : "";
    // Content prefix: through-connector for children with following
    // siblings, 3 spaces for last children and standalone rows; none when
    // the tree channel is absent (custom-ui off → native look).
    const contentPrefix = tree ? (inBranch ? tree.thoughtConnector(scope.last) : "   ") : "";
    const prefixWidth = contentPrefix ? visibleWidth(contentPrefix) : 0;
    // Thinking-anchored batch (§2.3): the anchor's row hosts the batch
    // header line above its own branch label. The header carries its own
    // OSC 8 batch link, so the label link is applied to the label only.
    const headerLine = scope.kind === "anchor" && tree ? tree.batchHeaderLine(scope.batchIndex) : undefined;
    // Leading blank line so the block stands apart; the trailing newline
    // separates the header from the branch label — none when collapsed
    // (nothing follows the header then).
    const headerPrefix = headerLine ? (anchorCollapsed ? `\n${headerLine}` : `\n${headerLine}\n`) : "";
    const labelFor = (canExpand: boolean) => {
      const api = customUiAnim();
      // Standalone rows keep the pre-tree presentation: one-space indent
      // with a blank line above and below (the old label Text's padding 1/1,
      // which branch/anchor rows must not inherit — they are flush tree
      // glyphs). The pad sits OUTSIDE the OSC 8 span.
      const standalonePad = (label: string) => `\n ${label}\n`;
      if (anchorCollapsed) {
        // The collapsed header IS the row (§2.2). The line carries its own
        // OSC 8 batch link; no glyph/label/thought URL of our own.
        return headerPrefix;
      }
      if (!completed) {
        const seconds = timing
          ? formatStreamingThinkingSeconds(record.now - timing.startedAt)
          : "0s";
        if (inBranch) {
          // Static streaming branch label — one-spinner rule: the batch
          // header (or the fresh-thinking row elsewhere) animates, not this.
          // staticLabel lives on the TREE channel (not the anim API) — it
          // renders inside the message component's render pass, where a
          // throw would crash pi (unlike guarded tool render slots).
          //
          // Wrap ONLY the label segment: headerPrefix may carry the anchor's
          // header line with its own batch OSC 8 span, and a nested opener
          // would close that span AND forfeit the thought link for every
          // cell after it (OSC 8 does not stack) — the anchor's branch label
          // must keep its own click target.
          const core = tree ? tree.staticLabel(`Thinking… ${seconds}`) : `Thinking… ${seconds}`;
          const label = tree ? tree.linkWrap(glyph + core, url) : glyph + core;
          return headerPrefix + label;
        }
        // Fresh thinking (no batch): the animated standalone label.
        if (api) {
          return standalonePad(
            api.streamingLabel(seconds, canExpand, `  (${record.options.toggleKey} to expand)`, message.timestamp, url),
          );
        }
        return standalonePad(createStreamingThinkingLabel(record.options, timing, record.now, canExpand));
      }
      if (!timing) return standalonePad(createStreamingThinkingLabel(record.options, timing, record.now, canExpand));
      const duration = formatThinkingSeconds(timing.completedAt! - timing.startedAt);
      // Expanded children carry the (click to collapse) suffix — the label
      // is the only collapse affordance. Collapsed labels stay bare (the
      // click affordance is the row itself; ctrl+o stays in pi's footer).
      const suffix = behavior === "full" ? "  (click to collapse)" : "";
      const core = api
        ? api.completedLabel(duration, false, suffix)
        : createCompletedThinkingLabel(record.options, timing, false) + suffix;
      if (inBranch) {
        // Same no-nesting rule as above: the label segment gets the thought
        // link; the header line keeps its own batch link.
        const label = tree ? tree.linkWrap(glyph + core, url) : glyph + core;
        return headerPrefix + label;
      }
      return tree ? standalonePad(tree.linkWrap(core, url)) : standalonePad(core);
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
      contentPrefix,
      prefixWidth,
      // Expanded reasoning is a click target like its label (click-to-
      // collapse); only when the tree channel is live (custom-ui on).
      tree ? url : "",
      // A branch that is the batch's last child ends the tree — it owes the
      // closing blank line (standalone rows already pad both sides).
      tree && inBranch && scope.last,
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

      prototype.updateContent = record.originalUpdate;
      setPatchRecord(undefined);
    },
  };
}
