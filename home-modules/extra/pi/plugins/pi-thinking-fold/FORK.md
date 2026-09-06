# pi-thinking-fold fork

Vendored fork of [`@99percentpeople/pi-thinking-fold`](https://github.com/99percentpeople/pi-extensions)
v0.1.9 (upstream source is the unminified TypeScript in their repo; the npm
tarball only ships the bundle). It replaces the npm-pinned version in
`pins.json`.

## Why

The custom-ui tool UI (`../lib/custom-ui.ts`) renders the transcript as an
interactive tree: each tool batch is a disclosure header (`▸/▾ Thought for
Xs · Ran N tool calls`), and thinking messages render as rows INSIDE the
tree — branch rows under their batch's header, standalone rows otherwise —
instead of upstream's flat `Thought for Xs (ctrl+t to expand)` line for
every assistant message. The fork is where all thinking rendering lives:

- a thinking message that streamed under an open batch (or anchored one as
  a leading think) renders as a tree branch: `├─ Thought for 30.1s`,
  hidden while its batch header is closed, reasoning expanding in place
  under the branch label (through-connector prefix when siblings follow);
- the FIRST leading think of a batch (the anchor) additionally hosts the
  batch header line at the top of its row — the header is animated by the
  lib's tick via the row's registered invalidator;
- a streaming branch renders a static `Thinking… 3s` label + preview (the
  animated batch header owns the one-spinner rule); fresh thinking (no
  batch) keeps the animated standalone label;
- expanded reasoning lines carry the thought's `pi-action://node/thought/`
  URL (click-to-collapse on the body, matching the label);
- standalone thinking keeps the pre-tree presentation: one-space indent
  with a blank line above and below the label (the old label padding),
  content indented 3 spaces. Branch CONTENT carries the through-connector
  `│  ` for EVERY branch — last included (a bare space indent under `╰─`
  reads as broken wrapping).

Branch scope/visibility come from the lib per timestamp (`branchScope(ts)`
on the `__piCustomUiTree` globalThis channel), as do the tree glyphs and
the anchor's header line. Nothing is absorbed: every reasoning block
renders at its true chronological position whenever its ancestors are open.

## Deviations from upstream

- `renderer.ts`:
  - `rebuild()`: consults the custom-ui tree channel
    (`__piCustomUiTree.branchScope`) instead of upstream's unconditional
    fold line. Children of a closed batch header render zero lines (pi's
    hidden-thinking path with an empty label; text blocks still render) —
    EXCEPT the anchor, which still hosts the collapsed header line (a
    collapsed header IS the row; the fork is its only host for anchored
    batches).
    Display behavior: streaming branches preview beneath a static label;
    completed branches collapse by default and open per their depth-3 flag
    (click / ctrl+o walk); standalone rows keep the configured behavior.
    On every rebuild the row registers an invalidator with the lib
    (`registerThoughtRow`) so tree state changes re-render it — the old
    "fold rows have no invalidator" gap, closed.
  - `RenderedThinkingSection` prefixes expanded content lines with the
    through-connector (`│  `) when the branch has following siblings (3
    spaces for last children and standalone rows) and renders content at
    `width − 3` so the prefix never wraps long.
  - Labels are click targets: `pi-action://node/thought/<ts>` OSC 8 spans
    (gated on the lib's link plumbing being live), tree glyphs prepended,
    and expanded children carry a `  (click to collapse)` suffix.
  - `setMessageTiming()`/`completeMessage()` publish completed durations to
    `globalThis.__piCustomUiThoughtFor` (`Map<messageTimestamp, ms>`) for
    the custom-ui extensions to look up — live and for restored sessions
    (upstream already reconstructs timings from message timestamps on
    `session_start`).
  - `beginMessage()`/`setMessageTiming()`/`completeMessage()` also mirror raw
    timings (`{startedAt, completedAt?}`) to
    `globalThis.__piCustomUiThoughtLive`, letting the custom-ui header
    count an in-progress reasoning block up in real time.
  - Upstream's `setExpanded` observer (global ctrl+o expand-all flag) is
    NOT re-applied: ctrl+o walks the whole tree via the lib
    (`installToolExpandWalk`).
- `shared-settings/`: upstream's `@99percentpeople/pi-shared-settings`
  package vendored verbatim (their build bundles it; we load plain TS, so the
  import is re-pointed to `./shared-settings/index.ts` in `config.ts` and
  `index.ts`).
- `package.json`: `scripts`/`piBuild` dropped — pi loads `./index.ts`
  directly, no bundling step.

## Rebase procedure

1. Fetch the upstream sources (note: `index.ts`/`package.json` filenames
   collide between `extensions/thinking-fold/` and `packages/shared-settings/`
   — download to distinct names):
   ```sh
   base=https://raw.githubusercontent.com/99percentpeople/pi-extensions/master
   curl -sL $base/extensions/thinking-fold/{LICENSE,README.md,config.ts,index.ts,model-behaviors.json,model-behaviors.ts,renderer.ts} .
   curl -sL $base/packages/shared-settings/index.ts -o shared-settings/index.ts
   curl -sL $base/packages/shared-settings/sectioned-settings-list.ts -o shared-settings/sectioned-settings-list.ts
   ```
2. Re-apply the deviations above (this file is the checklist; the patches are
   small and grep-anchored: `__piCustomUiThoughtFor`, `__piCustomUiTree`,
   `branchScope`, `hiddenThinkingLabel`, `registerThoughtRow`,
   `pi-shared-settings`).
3. Transpile-check every file:
   `bun build --no-bundle --external "*" <file>` (exit 0 each).
4. Bump `version` in `package.json` to the upstream version.
