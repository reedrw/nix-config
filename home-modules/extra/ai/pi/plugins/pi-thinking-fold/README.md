# @99percentpeople/pi-thinking-fold

Fold long, streaming reasoning blocks into a small live preview in Pi's TUI.
The preview follows the latest terminal-visible lines instead of letting a
reasoning trace continuously grow upward.

During thinking you see a compact tail preview with a live timer; afterwards
it collapses to `Thought for 12.3s`. Press `Ctrl+T` anytime to expand the full
reasoning trace. Behavior is tunable in `/99settings` (fold depth, while/
after-thinking strategies).

## Demo

### Trace models

A reasoning trace collapses to a stable tail preview with a timer, then to
`Thought for Xs (ctrl+t to expand)` — no more scroll-storms:

![thinking-fold trace demo](https://raw.githubusercontent.com/99percentpeople/pi-extensions/master/promo/demo/thinking-fold.gif)

### Summary models

A reasoning summary keeps its content folded while the working row shows the
latest summary headline, then collapses to the same completed timer:

![thinking-fold summary demo](https://raw.githubusercontent.com/99percentpeople/pi-extensions/master/promo/demo/thinking-fold-summary.gif)

## Behavior

When **While thinking** is set to `preview`, the assistant Item contains a
timed header and its latest terminal-visible lines:

```text
Thinking 7.1s  (ctrl+t to expand)
  checking the final branch…
  validating the result…
```

The cursor working row separately displays the plain status `Thinking...`. Model
behavior determines whether that row uses a summary headline (for example,
`Running focused tests`) or `Thinking...`. With the default `auto` streaming
behavior, summary content stays hidden while trace content shows a tail preview.

Cursor styling is intentionally outside this package. Install
[`@99percentpeople/pi-cursor-effect`](../cursor-effect/README.md) to apply the
optional wave effect to this and Pi's other main working-cursor labels.

The Item timer redraws only once per second. When reasoning finishes, the timer
freezes as soon as answer text or a tool call starts. The default `auto`
completion behavior hides content for every model, leaving a single line with
precise elapsed time. This also handles OpenAI-compatible providers that delay
their `thinking_end` event until the entire answer has streamed:

```text
Thought for 12.3s  (ctrl+t to expand)
```

Additional behavior:

- The `preview` strategy shows the latest 5 visual lines by default, for traces
  and summaries alike.
- Preview content keeps Pi's native Markdown formatting. Each thinking section
  is rendered at the current terminal width first, then the preview retains its
  final terminal-visible rows. Fences, headings, tables, quotes, lists, syntax
  highlighting, wrapping, and future Markdown behavior therefore need no
  syntax-specific handling, while the folded height stays fixed as formatted
  constructs enter or leave the tail window.
- Pi's normalized `thinking_start` / `thinking_delta` / `thinking_end` events
  drive streaming and timing, so model IDs never need per-model adapters.
- **While thinking** defaults to `auto`: summaries show only the timer while
  traces show their latest lines. Explicit `collapse` and `preview` override
  that model-aware choice.
- **After thinking** defaults to `auto`, which hides completed content for both
  summaries and traces. Explicit `collapse`, `preview`, and `full` override it.
- An empty Pi `thinking_start` still creates the timed Item. If a provider emits
  its entire summary immediately before `thinking_end`, the cursor keeps that
  headline visible for at least one second before `Responding…`.
- Models that expose neither a trace nor a summary transition directly to the
  normal `Responding...` working row without an extra availability warning.
- `Ctrl+T` (or the configured `app.thinking.toggle` binding) switches between
  the folded view and complete reasoning blocks. Its expansion hint appears
  only when content is actually hidden: by a `collapse` strategy, or because a
  thinking block exceeds the configured fold threshold. The chosen state
  persists across later turns until `Ctrl+T` is pressed again.
- `Ctrl+O` keeps its native Pi behavior and only expands tools and other
  expandable UI content.

The extension changes display-only message copies. Original assistant messages,
reasoning signatures, session persistence, and model context are not modified.
No extra session entries are added. After a reload, old durations are
reconstructed from Pi's message timestamps and are therefore approximate.

## Install

Build and install this checkout as a user-local development package:

```bash
bun run build:packages
bun run --cwd extensions/thinking-fold build
pi install ./extensions/thinking-fold
```

Or test without adding it to settings:

```bash
pi -e ./extensions/thinking-fold/index.ts
```

Remove the local package with:

```bash
pi remove ./extensions/thinking-fold
```

## Settings

Run the shared `/99settings` menu. It lists installed `@99percentpeople`
plugins that expose three independent display controls:

- **Fold after lines** (1–20): maximum terminal-visible lines retained by a
  `preview` display;
- **While thinking**: `auto` (hide summaries, preview traces), `preview`
  (latest lines), or `collapse` (timer only);
- **After thinking**: `auto` (hide every model), `collapse` (timer only),
  `preview` (latest lines), or `full` (all reasoning text).

Both behavior settings default to `auto`.

Settings persist globally in:

```text
~/.pi/agent/99extensions.json
```

under the `thinking-fold` namespace. The model behavior is always resolved from
the built-in model behavior configuration described below; an unmatched model
uses `trace`. Existing `previewLines` and `autoCollapse` settings are migrated
to the equivalent new values when next saved.

## Model behavior configuration

[`model-behaviors.json`](model-behaviors.json) is the package's single built-in
compatibility table. A rule selects by any combination of case-insensitive
JavaScript regular-expression sources in `api`, `provider`, and `model`:

```json
{
  "version": 1,
  "rules": [
    {
      "id": "responses-summary",
      "api": "responses$",
      "behavior": "summary"
    },
    {
      "id": "deepseek-trace",
      "provider": "^deepseek$",
      "model": "^deepseek-.*$",
      "behavior": "trace"
    }
  ]
}
```

Patterns are regex source strings without `/.../` delimiters; use `^` and `$`
when a full-field match is required. Invalid expressions fail validation at
startup. Rules with more selectors win, then `model` is considered more specific
than `provider`, and `provider` more specific than `api`; a later rule wins a
remaining tie.

The built-in table uses conservative API-family baselines:

| API/provider family | Behavior | Basis |
|---|---|---|
| OpenAI-compatible Chat Completions | `trace` | Pi reads `reasoning_content`, `reasoning`, or `reasoning_text` |
| Anthropic-compatible gateways | `trace` | Safe fallback because gateway semantics vary |
| Amazon Bedrock Converse | `trace` | Safe fallback because the model behind `reasoningContent` varies |
| Mistral Conversations | `trace` | Pi streams explicit `thinking` content items |
| `pi-messages` gateways | `trace` | Safe fallback for an intentionally generic protocol |
| OpenAI/Azure/Codex Responses | `summary` | Pi consumes `reasoning_summary_text` events |
| Google Generative AI/Vertex | `summary` | Pi consumes Google thought parts |
| First-party Anthropic | `summary` | Pi requests summarized thinking display |

The conservative Trace rules cover common providers such as OpenRouter, Groq,
Together, Fireworks, Cerebras, Hugging Face, Kimi, MiniMax, Moonshot, Qwen,
xAI Chat Completions, Z.AI, Xiaomi, NVIDIA, Mistral, and Bedrock through their
Pi API adapter. They do not claim that every routed model exposes a raw chain of
thought; Trace is chosen because it preserves visible content if an untested
backend differs. Provider/model-specific rules can override these API baselines
later.

Only the previously exercised OpenAI Responses, Google, and DeepSeek paths have
live model coverage in this repository. The additional families are validated
against Pi 0.82.1 adapter source and static fixtures, not paid provider calls.
The first config version intentionally supports only `trace` and `summary`, is
shipped with the package, and has no user override file. This keeps compatibility
data declarative and leaves provider/model names out of rendering code.

## Compatibility

Pi currently exports `AssistantMessageComponent` but does not provide an
extension hook for replacing normal assistant-message rendering. This package
therefore installs a guarded compatibility patch around the component's public
`updateContent()` method. It lets Pi create its native thinking `Markdown`
component, then wraps that display-only child so `render(width)` is evaluated
before its output is folded. The patch prevents duplicates across reloads and
restores the original method during session shutdown.

The package is tested against Pi 0.83.0. If the public component API is missing,
the extension disables itself and reports a warning. If Pi changes only the
internal child layout, an affected message safely falls back to complete native
rendering instead of exposing markers or modifying source content.
