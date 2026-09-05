# pi-thinking-fold fork

Vendored fork of [`@99percentpeople/pi-thinking-fold`](https://github.com/99percentpeople/pi-extensions)
v0.1.9 (upstream source is the unminified TypeScript in their repo; the npm
tarball only ships the bundle). It replaces the npm-pinned version in
`pins.json`.

## Why

The custom-ui tool UI (`../lib/custom-ui.ts`) renders one header per
tool batch (`✻ Ran N tool calls`). Upstream thinking-fold *also* renders a
completed `Thought for Xs (ctrl+t to expand)` line for every assistant
message, so a thinking→tools turn spends two lines repeating the same
information. The fork merges them:

```
✻ Thought for 3.5s · Ran 6 tool calls (ctrl+o to expand)
```

The live tail preview while thinking streams is unchanged (that's why we fork
instead of dropping the package).

## Deviations from upstream

- `renderer.ts`:
  - `rebuild()`: assistant messages that contain tool calls render **no**
    thinking line (pi's hidden-thinking path with an empty label — zero
    output lines) when `customUi` is enabled in settings.json and the user
    hasn't explicitly expanded with ctrl+t. The thinking duration instead
    rides the custom-ui batch header.
  - `setMessageTiming()`/`completeMessage()` publish completed durations to
    `globalThis.__piCustomUiThoughtFor` (`Map<messageTimestamp, ms>`) for
    the custom-ui extensions to look up — live and for restored sessions
    (upstream already reconstructs timings from message timestamps on
    `session_start`).
  - `beginMessage()`/`setMessageTiming()`/`completeMessage()` also mirror raw
    timings (`{startedAt, completedAt?}`) to
    `globalThis.__piCustomUiThoughtLive`, letting the custom-ui header
    count an in-progress reasoning block up in real time.
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
   small and grep-anchored: `__piCustomUiThoughtFor`,
   `customUiMergeEnabled`, `hiddenThinkingLabel`, `pi-shared-settings`).
3. Transpile-check every file:
   `bun build --no-bundle --external "*" <file>` (exit 0 each).
4. Bump `version` in `package.json` to the upstream version.
