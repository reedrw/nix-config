---
name: pi-ui
description: Architecture and hard-won constraints of the custom-ui pi extension suite (home-modules/extra/pi/plugins/) — read before editing anything in plugins/
---

Load this skill before editing any file under `home-modules/extra/pi/plugins/`.
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
- **thinking-fold lives inside the suite** (`lib/thinking-fold/`, the former
  vendored `pi-thinking-fold` package; the former `thinking-fold-redraw.ts`
  shim is the deferred-repaint listener inside `installThinkingFold`). It is
  installed by `custom-ui.ts` unconditionally BEFORE the `customUiEnabled()`
  gate — with the style off it still folds reasoning in pi's native look.
  Because it shares the entry's module graph, the old globalThis channels are
  gone: the fold imports the lib's tree helpers (`branchScope`,
  `forkBatchHeaderLine`, glyphs, `registerThoughtRow`) and `animState()`
  directly, and publishes timings via the lib's `noteThinkingTiming` /
  `thoughtTiming` registry (`__piCustomUiThoughtTimings` — still globalThis:
  the lib is instantiated per extension entry, and /reload keeps globalThis).
  Multi-file `lib/<dir>/` trees are packaged recursively by
  `plugins/default.nix` (all regular files, relative paths preserved — JSON
  data and LICENSE included). ALL lib files ship in ONE derivation: node/jiti
  resolve imports to each file's REAL store path (symlinks dereferenced), so
  per-file derivations strand lib-internal relative imports (`../custom-ui.ts`)
  in a sibling store path that doesn't exist. Symptom was "Cannot find module
  './shared-settings/index.ts'" at extension load.
- **Theme coupling is a three-tier resolver**: all raw-SGR color goes through
  `base16Fg`/`base16Bg` (lib): (1) the nix-generated stylix palette at
  `~/.pi/agent/extensions/lib/base16.json` wins when present — exact scheme;
  (2) the live pi `Theme` — roles mapped per base16 name in `THEME_FG_ROLES`/
  `THEME_BG_ROLES` (getFgAnsi/getBgAnsi THROW on absent colors — try the next
  role); returns the theme's own SGR, correct for the terminal's color mode;
  (3) static Ayu Dark hexes. custom-ui.ts's `session_start` (first ctx-bearing
  event) publishes `setLiveThemeSource(() => ctx.ui.theme)` — `ctx.ui.theme` is
  a live getter over pi's theme singleton, so `/theme` changes are tracked
  with no event hook; the source lives on globalThis (shared by every lib
  instance). The shimmer gradient parses theme RGB ONLY in truecolor mode
  (`themeNameRgb`); 256color keeps static fallbacks (no honest RGB). Cache
  keys: shimmer palettes key on palette epoch + theme instance id (WeakMap)
  + color mode + stops; the smoke's theme-tier section must use stops unique
  to that section (cache keys don't distinguish palette CONTENT within the
  500ms TTL, so reused stops can hit entries computed under an earlier
  palette state). Without the palette file the bands follow the theme's
  polarity (light theme → light band) instead of rendering dark Ayu bands
  under light-theme text.
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
  exposes no requestRender. The fold consumes ctrl+t and mutates components,
  so folds would apply only on the next key. Fix (inside `installThinkingFold`'s
  session_start): a non-consuming listener registered BEFORE the toggle
  listener fires first, matches the same keybinding, and defers a render one
  tick via the shared anim handle (`animState().requestRender`, captured from
  a zero-line `setWidget` factory in custom-ui's session_start; widgets,
  unlike footers, can be additive).

## Transcript tree & the one Thinking indicator

- **Tree model**: the transcript is an interactive tree. Every tool batch is
  a disclosure header (`▸/▾ Thought for Xs · Ran N tool calls` — bold grey
  base03, italic, one leading space; collapsed by
  default when settled); glance rows and thinking branches are its children
  (`├─`/`╰─`, visible iff the header is open, one column in so the glyphs sit under the header's `▾` — every child prefix, continuation, and output rail shares that column);
  each child's output/reasoning is depth 3 (visible iff the child is open).
  `│` appears ONLY as the through-connector on the content lines of an
  expanded mid-list child (`│  ` = 3 cells for thinking, `│` + the 5-cell
  result indent for tool output); the last child (`╰─`) has no connector.
  **wrapTreeText** (lib, used by PrefixedText instead of pi-tui's
  wrapTextWithAnsi): splits tokens after `- _ / . ,` and spaces, hard-breaks
  split-less runs at the width, fills lines to the brim (no stranded stubby
  heads), re-opens the active OSC 8 link + SGR state on every continuation
  and closes them at each line end. Hard `\n` = forced break. Do NOT patch
  pi-tui's wrapper for this — the lib owns the tree wrapping.
  Expanded CONTENT is clickable too: thinking text (fold renderer) and tool output
  (`ClickToggle` around every `expandedBlock`/`liveStream`/edit diff) carry
  the node's own toggle URL per line, so clicking the body collapses it.
  A batch whose LAST child is a thinking branch ends with one blank line
  (fold `trailingBlank`, set when `scope.last`) — tool children get their
  separation from the next block's own spacing, branch rows must supply
  it themselves. Standalone thoughts pad both sides as before.
- **OSC 8 does NOT stack**: an inner `]8;;` opener silently closes the
  outer span, and nothing after the inner closer is linked. NEVER nest or
  whole-line-wrap when a segment already carries a link (e.g. the anchor
  row: wrap ONLY the `├─ Thought…` label with the thought URL — the header
  line inside it keeps its own batch URL). Turn-summary thinking time is
  clamped per message to its wall span and capped at the turn duration —
  leaked live entries (aborted streams) must not inflate it.
- **`linkWrap` is URL-aware**: it splits every wrapped string into runs —
  bare URLs (`https?://`, `www.`; trailing sentence punctuation/unmatched
  closers trimmed, `www.` target gets `https://`) and pre-existing OSC 8
  spans stay opaque and keep a plain hyperlink that just opens the target;
  only the remaining text gets the pi-action toggle URL. pi's Markdown emits
  no OSC 8, so URLs in reasoning/tool output are plain text and are linkified
  here; this also means URLs stay clickable in regular (non-fullscreen) mode
  (URL links are emitted whenever `getCapabilities().hyperlinks`, the action
  link still requires `linksEnabled()`). Adding another raw `]8;;` wrapper
  around rendered text re-introduces the nesting bug — route it through
  `linkWrap`.
- **pi's dist is NOT patched anymore**: the former `pkgs/alias.nix` postFixup
  seds (wheel scroll ×5 in fullscreen, framing blank above self-shell tool
  rows) are extension prototype patches now — `wheel-scroll.ts` patches
  `TuiAltScreen.prototype.routeWheel` (direction ×N ≡ wheelScrollLines = N;
  N comes from `wheelScrollLines` in settings.json, default 5), and the lib's `installTightSelfRows`
  strips the blank pi pushes above every self-shell row plus shifts
  `handleMouse` events back (post-0.84 upstream assumes the blank line for
  click y-coordinates — feature-detected). Module identity with pi's own
  imports is guaranteed: the extension loader's jiti alias table resolves
  `@earendil-works/pi-tui` / `@earendil-works/pi-coding-agent` to pi's own
  module instances (loader.js `getAliases()`), so prototype patches from
  extensions reach the real classes. Don't re-add dist seds.
- **Untracked-row repaint**: pi renders a tool's call row during arg
  streaming (before the `tool_call` event) and renders a restored
  transcript before `session_start`'s rescan — both first passes render
  UNTRACKED (normal mode = full-width call line, no glyph/rail; this was
  the "long word wraps at column 0" bug). Fixes: `trackGroupToolCall`
  invalidates the row it tracks, and `scanToolGroupsFromHistory` snapshots
  the pre-scan invalidator registry and re-fires it for ids the scan
  tracks (resetToolGroups would otherwise wipe the registry and leave
  those rows untracked forever).
  Children (tool ids + thinking timestamps) merge into one chronological
  `children` list per batch — renderers walk it to place `├─`/`╰─`.
- **Header diffstat**: once Edit calls in a batch settle, the header gains
  a summed `+N −M` section (green/red) — a SEPARATE OSC 8 span after the
  header link (never nested — an inner opener closes the outer). Clicking
  it (`pi-action://node/edits/<i>`) sets `batch.editsOpen`, a batch-wide
  override of edit-row output flags (dissolved by per-row toggles or
  ctrl+o walks), and OPENING also opens the batch header — one click
  straight to the changes. A SOLO batch of exactly ONE node (1 tool call,
  NO reasoning block, non-edit) also toggles that call's output when the
  header is clicked — one click expands the block; anything bigger grows
  node by node, and an EDIT's output only opens via the diffstat click. The diffstat is a FULL toggle: its second click
  collapses the header it opened (a user-opened header survives). Auto-
  open of the newest child's output (16-line cap) does NOT apply to solo
  trees carrying a reasoning block (1 tool + thoughts): their streaming
  tool shows only its call row — treeCall keeps `isPartial` call rows
  visible and the partial glance yields to it.
- **State machine**: batch open/closed is USER state with live defaults
  (`open?` + `stickyClosed?` on each batch; `openTools`/`closedTools`/
  `openThoughts` sets on the state). A RUNNING batch auto-opens and its
  newest child auto-opens with a 16-line cap; a user collapse of a running
  batch is sticky (wins over auto-open until re-open); settled batches
  default closed; user-opened children persist. There are NO derived
  `collapsed`/`folded`/`latest` flags and no `effectiveExpanded` precedence
  chain — clicks flip exactly one node's flag (`pi-action://node/batch/<i>`,
  `node/tool/<id>`, `node/thought/<ts>` OSC 8 links, fullscreen only), and
  ctrl+o walks every node via `walkTree` (the lib observes
  `ToolExecutionComponent#setExpanded` once per gesture, deduped within
  50ms — pi fires it per row). `scanToolGroupsFromHistory` mirrors the live
  rules on restore.
- **Leading thoughts anchor the batch (§2.3)**: a contiguous run of
  pure-thinking messages directly before a batch's first tool call joins it
  — the FIRST becomes the anchor and HOSTS the header line in the fold
  renderer (via the lib's `forkBatchHeaderLine` + linkWrap, direct imports); the
  rest are ordinary branches. Visible text or a user message dissolves the pending
  run (hosting would reorder the think past the narration). No absorption:
  thinking always renders at its true chronological position whenever its
  ancestors are open — a branch of a closed header renders zero lines
  (fold's stripped-message path). The fold registers a per-timestamp
  invalidator (`registerThoughtRow`) on first render so tree state changes
  (anchor assignment, open/close, `╰─`→`├─` reglyphing, tick-driven header
  animation) re-render thought rows — the old "fold rows have no
  invalidator" gap is closed, and `__piCustomUiRerenderThought` nudges are
  gone with it.
- **One Thinking indicator (unification rule)**: the running batch header is
  the ONLY animated element while a batch runs (`batchHeaderAnimated()` = a
  batch is running — every running batch has a visible live header, even
  solo and sticky-closed; the dead-air loader reads it). A thought streaming
  mid-batch renders a branch row with a STATIC `Thinking… 3s` label +
  preview; fresh thinking (no batch) keeps the animated standalone label
  ({ frame, batchOpen, spinnerFrame, inProgressDot, streamingLabel, tick } —
  shared clock; base16 SGR, no Theme needed). pi's loader is hidden on
  thinking_delta (`setWorkingVisible(false)`), restored on
  tool_call/text_delta/user message/agent_end — NOT on thinking_end
  (flicker between consecutive thinking blocks). The fold's streaming label
  must render through a pi-tui **Text**, not Markdown (raw SGR gets
  mangled); its timer runs at 80ms. The in-progress tool dot is dotsCircle
  (2-cell frames, spaces are anti-wiggle padding — do not trim).

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

`plugins/typecheck.sh` is the gate: it rebuilds the dev `node_modules` of
symlinks into the installed pi and runs `tsc --noEmit`, which is now **clean —
any error it prints is yours**. Runtime never uses that dir (pi's jiti loader
aliases `@earendil-works/*` itself; the nix package ships no node_modules), but
tsc needs real files. The script exists because hand-rolling the symlinks is
error-prone, and one omission is silent and vicious: without
`@earendil-works/pi-ai` on disk, `import type { AssistantMessage }` becomes
`any` and every use site cascades into `TS7006 implicitly has an 'any' type` —
which reads like sloppy code, not a missing symlink. Notes it encodes:
`node_modules/` must be a REAL dir (a symlinked one breaks resolution — the
store is read-only), `@earendil-works/` must be a real dir too (the store's own
`@earendil-works` dir has no `pi-coding-agent`, and `pi-coding-agent` must
resolve to the monorepo root), and every bundled `@earendil-works/*` package is
linked (pi-ai, pi-agent-core, pi-tui, …). Re-run it after a pi update; it finds
pi via `readlink -f "$(command -v pi)"` minus `/bin/pi`. The tracked
`plugins/package.json` (`"type": "module"`) is a typecheck-scope marker only —
never installed; without it NodeNext infers CJS and
`lib/thinking-fold/model-behaviors.ts`'s `import.meta` usage fails with TS1470.

Strict `tsc` finds missing imports that jiti only surfaces as runtime
ReferenceErrors which pi then swallows (renderer fallback / event-handler error
log). When image-history.ts was merged into custom-ui.ts, six dropped imports
(node:crypto/fs/url + lib helpers) silently killed inline image embedding, the
history-entry fallback, and read-row rendering — the TS2304s were the only
signal. Take TS2304s seriously. Scope: tsconfig includes `*.ts` + `lib/**/*.ts`
(the fold was outside the old include — keep new code inside it). When the
include scope changes, regenerate a baseline from the pre-change tree with the
NEW tsconfig (`git archive <base> … plugins | tar -x`, copy `tsconfig.json`,
run the same symlink setup) and diff — otherwise new coverage reads as new
errors.

`smoke.mjs` (tracked) drives the grouping state machine + header renderers
headlessly under `nix run nixpkgs#nodejs -- --experimental-transform-types smoke.mjs`
— the working-tree lib imports run without pi, so renderer changes can be
asserted without a live TUI. It MUST be deterministic: **never `await` a fixed
sleep** before asserting on a deferred repaint. The suite is synchronous until
its first `await`, so every `setTimeout(0)` the lib scheduled is backlogged and
drains in one burst there; the repaint chain is nested (`invalidate →
setTimeout → re-render`), so a 10 ms sleep regularly expired between the two
hops and looked like a broken change ("rescan must repaint pre-scan rows…"
threw ~50 % of runs on an untouched tree — agents then chased a phantom
regression). Use the `waitFor(what, predicate, detail)` helper (polls every
5 ms, 2 s cap) for anything async — it waits for the second hop instead of
racing it.

## Debugging pi's TUI headlessly

`script -m advanced -qec "TERM=xterm-256color pi …" --log-timing t.log io.log`
gives byte-level I/O timing of a real pi instance. Limits: a dumb pty never
answers pi's kitty-keyboard negotiation, so app-action keys (ctrl+t etc.) never
fire in the harness — only TUI-global keys (PageUp) and plain typing work;
keybinding bugs need the real terminal. Exit dumps produce huge output bursts
easily mistaken for live repaints — bucket the timing log.
