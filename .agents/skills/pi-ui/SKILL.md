---
name: pi-ui
description: Architecture and hard-won constraints of the custom-ui pi extension suite (home-modules/extra/ai/pi/plugins/) — read before editing anything in plugins/
---

Load this skill before editing any file under `home-modules/extra/ai/pi/plugins/`.
The extensions implement a custom tool UI (batched tool calls, folded reasoning,
inline images, compact user messages). Most of the constraints below were learned
the hard way; violating them fails silently.

## Ownership & module layout

- **Tool-name ownership is exclusive**: only one extension may `registerTool` a
  given name (pi errors on conflicts). `bash` is owned by `nix-comma.ts` (spawn
  hook); `custom-ui.ts` owns everything else, including `read` with inline
  kitty-placeholder image rendering (functionality merged from the former
  image-history.ts — no separate extension anymore).
- Rendering slots are shared via `plugins/lib/custom-ui.ts` (a `lib/` plugin kind —
  not auto-loaded by pi, but installed to `~/.pi/agent/extensions/lib/` for
  `./lib/…` relative imports).
- **Register tools at LOAD time, never in `session_start`**: pi's session-switch
  flows (in-app `/resume`, `/new`, `/fork`, tree navigation) render the restored
  transcript BEFORE re-binding extensions (`rebindCurrentSession({
  renderBeforeBind: true })` → `renderCurrentSessionState()` first). A tool
  first registered in `session_start` renders that first pass with pi's
  built-in renderer; the row also predates the post-bind grouping rescan, never
  registers a row invalidator (`trackRow` runs only in custom render slots),
  and if it's the batch's first member it permanently swallows the batch
  header. Symptom was "skill loads break tool grouping on resume": the agent
  reads SKILL.md (pi renders that read compactly as `[skill] name`), so the
  headerless glance rows dangled under the native `[skill]` row. `read` was the
  offender; `execute` must still resolve paths per session cwd, so the
  definition is registered once at load (`process.cwd()`) and rebuilt per
  `ctx.cwd` inside `execute` (same pattern as edit/write/grep/find/ls).
- **Shared state must live on `globalThis`**: each extension may get its own module
  instance of the lib, so cross-extension state (e.g. tool batch tracking) uses a
  `globalThis` singleton (`__piCustomUi*` keys), not module scope.
- `genericSlots(label, argOf)` in the lib gives any tool the full treatment in ~3
  lines; `pi.getAllTools()` exposes no `execute`, so third-party/MCP tools cannot
  be re-rendered generically.

## Rendering pitfalls

- **Never call `context.invalidate()` synchronously from a render slot**: it
  re-enters the row's `updateDisplay()` mid-rebuild and duplicates every
  component. Defer with `setTimeout(0)` (see `settleStatus`).
- **Renderer exceptions are silent**: pi catches slot exceptions and swaps in its
  fallback renderer (raw truncated output). A TDZ/ReferenceError in a renderer
  looks like "glances disappeared". Debug by running a real session JSONL through
  `scanToolGroupsFromHistory` + renderers with a mock theme and count throws.
- **`ctx.ui.notify` is not hookable** (no renderer/event); prefer folding notices
  into tool-result content (a `tool_result` handler may return replacement
  `content`) — see `nix-comma.ts`.
- **Consumed input suppresses repaint**: the TUI input loop `return`s on
  `{ consume: true }` from `onTerminalInput` listeners BEFORE the
  `requestImmediateRender()` that follows every keypress, and the UI context
  exposes no requestRender. pi-thinking-fold consumes ctrl+t and mutates
  components, so folds apply only on the next key. Fix: `thinking-fold-redraw.ts`
  shim — global extensions load before configured packages (loader discovery
  order: project `.pi/extensions/` → `~/.pi/agent/extensions/` → settings.json
  packages), so its listener sees ctrl+t first and defers a render via a TUI
  handle captured from a zero-line `setWidget` factory (same capture trick as the
  statusline footer; widgets, unlike footers, can be additive).

## Grouping & the one Thinking indicator

- **Grouping rule**: consecutive tool calls form a batch; reasoning folds it
  visually (header + glance rows appear immediately) without closing it; visible
  assistant text, a user message, or `agent_end` closes it. **Narration
  exemption**: a message shaped thinking→text→toolCall keeps its fold row (visible
  text split the batch); its thinking is NOT stamped into the next batch header
  (custom-ui stamping + lib scan both skip narrated messages), and the fork's
  merge never strips a narrated message's fold — stripping a visible row was the
  missing-fold regression.
- **One Thinking indicator (unification rule)**: three surfaces used to show
  "Thinking" at once — pi's native loader row, the thinking-fold streaming row,
  the custom-ui batch header. Rule (v3): the batch header ALWAYS animates for the
  whole batch run; during batch thinking the fold row streams label-less (fork
  labelFor returns "" while `__piCustomUiAnim.batchOpen` — just reasoning preview
  beneath the header); fresh-thinking rows (no batch) get the full animated label
  ({ frame, batchOpen, spinnerFrame, inProgressDot, streamingLabel, tick } —
  shared clock; base16 SGR colors, no Theme needed). pi's loader is hidden on
  thinking_delta (`setWorkingVisible(false)`), restored on tool_call/text_delta/
  user message/agent_end — NOT on thinking_end (flicker between consecutive
  thinking blocks). The fork's streaming label must render through a pi-tui
  **Text**, not Markdown (raw SGR gets mangled); its timer runs at 80ms. The
  in-progress tool dot is dotsCircle (2-cell frames, spaces are anti-wiggle
  padding — do not trim) and solo batches tick so it animates.
- While a batch's header is visible (folded, or ≥2 tools so the first row became
  "earlier"), `tickOpenBatch` animates it on an 80 ms timer (`ensureTick` in
  custom-ui.ts, restarted by tool_call/thinking_delta, self-stopping): dots
  spinner (random variant per batch, cli-spinners frames) + shimmer verb
  (pi-animations' shimmer recolored to a base0D→base0E→base0C stylix gradient
  over base04, raw truecolor SGR — beyond theme.fg) + zentui's verb catalog
  (deterministic per batchIndex). Settled batches render the static `✔` header;
  restored ones too, so animation state needs no persistence. The shimmer palette
  is memoized — base16.json is read once per process, so /theme switches
  mid-session don't recolor it. Thinking durations (live and restored, via the
  pi-thinking-fold fork's `__piCustomUi*` globalThis maps) surface in the batch
  header. Extension notifications (`ctx.ui.notify` info level) fold into the open
  batch via the patched `showExtensionNotify`. Restored sessions rebuild batches
  via `scanToolGroupsFromHistory` on `session_start`.
- **pi-thinking-fold is a vendored fork** (`plugins/pi-thinking-fold/`, see its
  FORK.md): thinking lines fold into the custom-ui batch headers instead of
  rendering their own line. Its deviations from upstream are greppable
  (`__piCustomUi`).

## Compact user messages & `!` shell commands

Both share the compact look via prototype patches in custom-ui.ts:
`installCompactUserMessages` rewrites `UserMessageComponent.prototype.render`
(rail + base01 band, reusing the child Markdown); `installCompactBashCommands`
post-processes `BashExecutionComponent.prototype.render` output instead of
rebuilding it, so streaming/loader/truncation/expansion keep working — it drops
the full-width `─` DynamicBorder rows (strip SGR, then
`plain.length === width && /^─+$/`) and prefixes each line with a
`theme.fg("warning", "▎")` rail (warning = base0A yellow under the
stylix-generated theme in pi/default.nix) over `base16Bg("base01")`.
`BashExecutionComponent` is exported from the package root and used for both live
runs and history rebuilds, so one prototype patch covers both;
`excludeFromContext` (`!!`) is not observable from render output, so `!` and `!!`
render identically. While a command runs, the patch also retargets the `Loader`
on first render (found via `contentContainer.children` + `instanceof`, one-shot
per instance in a WeakMap): its `frames`/`spinnerColorFn`/`messageColorFn` are
TS-private but plain runtime fields — a plain structural view must be used, since
intersecting with `Loader` (which declares them private) collapses the type to
`never`. The loader's own 80ms tick drives both the random cli-spinners dots
variant and the "Running…" shimmer (yellow→orange→red, base0A→09→08 —
`shimmerFrame` in the lib takes optional gradient stops; the default remains the
batch header's cyan/purple), no timer of our own. Spacing is normalized in the
same post-process: output ending in `\n` leaves a blank `outputLines` entry that
stacks with the loader/status row's own leading blank, so blank runs are
collapsed to one and a single trailing blank is appended — the spinner/status row
ends up with one blank line before and after.

## Typecheck + smoke gates (run before committing plugin changes)

Strict `tsc --noEmit` over the plugins dir finds missing imports that jiti only
surfaces as runtime ReferenceErrors which pi then swallows (renderer fallback /
event-handler error log). When image-history.ts was merged into custom-ui.ts, six
dropped imports (node:crypto/fs/url + lib helpers) silently killed inline image
embedding, the history-entry fallback, and read-row rendering — the TS2304s were
the only signal. Take TS2304s seriously.

Setup: the plugins dir has a tracked `tsconfig.json` (strict, NodeNext) and needs
an **untracked real `node_modules/` dir** of symlinks (a symlinked `node_modules`
itself fails — /nix/store is read-only): every entry of pi's bundled
`node_modules/*`, plus `@earendil-works/pi-coding-agent` → the monorepo root and
`@earendil-works/pi-tui` → pi's bundled
`node_modules/@earendil-works/pi-tui` (the store monorepo has no `packages/`
dir). Find the store path with `readlink -f "$(command -v pi)"` and strip
`/bin/pi`. Always diff errors against a baseline of the pre-change tree (e.g.
`git archive <base> … plugins | tar -x` + same tsconfig) — only *new* errors
count.

`smoke.mjs` (tracked) drives the grouping state machine + header renderers
headlessly under `nix run nixpkgs#nodejs -- --experimental-strip-types smoke.mjs`
— the working-tree lib imports run without pi, so renderer changes can be
asserted without a live TUI.

## Debugging pi's TUI headlessly

`script -m advanced -qec "TERM=xterm-256color pi …" --log-timing t.log io.log`
gives byte-level I/O timing of a real pi instance. Limits: a dumb pty never
answers pi's kitty-keyboard negotiation, so app-action keys (ctrl+t etc.) never
fire in the harness — only TUI-global keys (PageUp) and plain typing work;
keybinding bugs need the real terminal. Exit dumps produce huge output bursts
easily mistaken for live repaints — bucket the timing log.
