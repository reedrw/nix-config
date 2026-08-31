# AGENTS.md

This file provides guidance for AI coding agents when working with code in this repository.

## Key Commands

Run `ldp` to build and switch the current host (`ldp --help` for boot/build variants).

**Enter the dev shell** (provides home-manager, nix-update, shellcheck, update-all, doppler; also activates pre-commit hooks):
```sh
nix develop
```
`.envrc` uses `use flake`, so direnv enters this shell automatically.

**Important:** Nix flakes only see git-tracked files. New files must be `git add`-ed (staged) before they are visible to `nix build`, `nix flake check`, etc. Untracked files are silently ignored.

The flake requires the `pipe-operator` experimental feature. Commands in `install.sh` pass `--experimental-features 'pipe-operator nix-command flakes'` automatically.

## Architecture

This is a NixOS + home-manager configuration managed as a flake using **flake-parts**, **ez-configs**, and **haumea**.

### Flake structure

- `flake.nix` — inputs and flake-parts entry point; delegates to `./repo`
- `repo/default.nix` — configures ez-configs, maps hosts to users, exposes `util` helpers
- `repo/extraEzModules.nix` — makes all modules available as `ezModules'` special arg via haumea
- `repo/git-hooks/` — pre-commit hooks (statix, deadnix, shellcheck, trim-whitespace, plus custom `no-rec` and `no-empty-module-arg`) via `git-hooks-nix`; injected into the dev shell automatically
- `repo/stage/` — VM staging scripts used by the `/stage` skill (`stage.sh` plus primitives `run.sh`, `wait.sh`, `shoot.sh`, `ssh.sh`, `sendkey.sh`, `stop.sh`)
- `repo/compat.nix` — flake-compat shim for `shell.nix` and legacy tooling

### Module auto-loading

Two different module-aggregation mechanisms work side-by-side, both passed as special args:

- **`ezModules.<category>`** (from ez-configs) — each top-level subdirectory of `nixos-modules/` and `home-modules/` becomes an attr that pulls in *every* module in that directory at once. Each category directory has a tiny `default.nix` that `readDir`s itself and imports its siblings. Host configs typically just write `imports = [ ezModules.core ezModules.custom ezModules.extra ... ]`.
- **`ezModules'.<path>.<to>.<file>`** (from haumea) — haumea recursively loads every `.nix` file into a nested attrset mirroring the directory tree. Used at the **host level** to cherry-pick individual modules across category boundaries (e.g. `ezModules'.users.reed`, `ezModules'.extra.sshd`, `ezModules'.networking.networking`).

In short: inside a category, modules don't need to reference each other through `ezModules'` — `default.nix` already pulls them all in. `ezModules'` exists so a host can opt into one piece of a category without taking the whole thing.

**ez-configs** (`github:ehllie/ez-configs`) wires NixOS and home-manager configurations from:
- `nixos-configurations/<hostname>/` → `nixosConfigurations.<hostname>`
- `home-configurations/<user>/` and `home-configurations/<user>@<hostname>/` → `homeConfigurations.<user>`

`mkUserHomeModules` in `repo/default.nix` maps home users to hosts; host-specific user configs (e.g. `reed@nixos-desktop`) override the default `reed` config when present.

### Directory layout

```
nixos-configurations/   # Per-host NixOS entry points
  nixos-desktop/
  nixos-t480/
  nixos-t400/
  nixos-vm/
  nixos-iso/
  <host>-no-home-manager.nix   # Variants of desktop/t480/t400 without home-manager baked in

home-configurations/    # Per-user (and per-user@host) home-manager entry points
  reed.nix
  nixos.nix
  reed@nixos-desktop/
  reed@nixos-t480/
  ...

nixos-modules/          # Reusable NixOS modules — each category has a default.nix that imports its siblings
  core/                 # Always-on: nix, kernel, zsh, home-manager integration, styling, run0, tweaks, gnupg, power
  custom/               # Site-specific: persist (impermanence), display (custom.display scaling), snapper, steam, nix-ssh-serve, vm-staging, boot/, games/
  extra/                # Opt-in: sshd, logitech, actualbudget, android/
  graphical/            # GUI: fonts, opengl, sound, wlr
  networking/           # networking defaults, autoupdate, avahi, bluetooth, firewall, mullvad, printing, tailscale
  virtualization/       # docker, libvirt
  users/                # System user definitions (cherry-picked via ezModules'.users.<name>)

home-modules/           # Reusable home-manager modules — same category-default.nix pattern
  core/                 # nvim, zsh, ssh, persist, stylix styling, nixpkgs config, functions, comma
                        # themes/stylix.json (pi theme generated from the
                        # stylix scheme, ported from stylix PR #2488) and
                        # settings.json theme = "stylix"; upstream stylix's
                        # pi-coding-agent module is NOT used (it's gated
                        # behind HM's programs.pi-coding-agent option)
  extra/                # git, mullvad, gnupg, ai (claude-code + pi-agent), proc, base, ranger, gnome-keyring
                        #   pi module: everything under extra/ai/pi/plugins/ is installed
                        #   automatically — *.ts files become extensions; subdirs with a
                        #   package.json are vendored; pins.json roots are npm tarballs
                        #   pinned with SRI hashes (update pins via plugins/update.sh,
                        #   also run by `update-all`)
                        # skills/ — pi agent skills (dirs with SKILL.md), installed
                        #   to ~/.pi/agent/skills/ by pi/default.nix; helper scripts
                        #   there are writeShellApplication wrappers so they pin
                        #   their own deps (e.g. web-search bundles ddgr)
  graphical/            # sway, kitty, firefox, flameshot, obs, bitwarden, fontconfig, anki
  games/
  media/                # mpd, mpv, zathura, pipewire, librepods
  social/               # signal, telegram, discord, weechat
  filesharing/

pkgs/                   # Custom packages, overlays, and pkgs-extension helpers
  overlays.nix          # Lists the overlays composed in order: branches, default, alias, functions
  default.nix           # myPkgs attrset → inherited and spread via `// myPkgs` so packages are accessible as `pkgs.<name>`
  config.nix            # nixpkgs config (allowUnfree, permittedInsecurePackages)
  branches.nix          # Adds `nur` and `mv` (nixpkgs-multiverse) to the pkgs set
  alias.nix             # Overrides specific upstream packages (patches for adwsteamgtk, jellyfin-mpv-shim, lix, updog, etc.)
  functions.nix         # Helper functions added to pkgs set (see below)
  patches/              # Local patch files used by alias.nix overrides
  <tool>/               # One directory per custom package/script (ldp, gc, jdownloader, mountiso, unscene, update-all, wheel-wizard, persist-path-manager, xdcc-dl, xdcc-tar)
```

### Useful helpers from `pkgs/functions.nix`

These are added to the pkgs set, so `pkgs.<helper>` works anywhere:

- `pkgs.mullvadExclude pkg` — wrap `pkg` so its main binary runs via `mullvad-exclude` (no-op when wrapper isn't present)
- `pkgs.wrapEnv pkg { VAR = "val"; }` — wrap a package's main program with exported env vars
- `pkgs.wrapPackage pkg (binPath: "shell script body")` — generic wrapper around a package's main program
- `pkgs.aliasToPackage { name1 = "shell body"; name2 = "..."; }` — turn a set of one-liners into a single derivation containing those binaries (used for "global aliases")
- `pkgs.writeNixShellScript name text` — promote a `nix-shell` shebang script to a `writeShellApplication` with runtime inputs parsed from the shebang. The script's **second line** must be `#! nix-shell -i bash -p <pkg1> <pkg2>` — packages listed there become the Nix `runtimeInputs`. Typical usage: `pkgs.writeNixShellScript "foo" (builtins.readFile ./foo.sh)`
- `pkgs.matchPackage "foo.bar.baz"` — resolve a dotted package path against the pkgs set
- `pkgs.matchPackageCommand "foo --args"` — like `matchPackage`, but takes a command string and replaces the leading package name with the absolute path to its main binary
- `pkgs.writeShellApplication` — drop-in override of the nixpkgs builder that also accepts a function `(self: { ... })` in place of `rec` (which is banned repo-wide)

### Theming

Theming uses **Stylix** (`github:nix-community/stylix`). `config.stylix.polarity` is `"dark"` or `"light"` in any home-manager module (re-exported from `osConfig` by the core styling module). Use it to branch theme values:

```nix
theme = if config.stylix.polarity == "light" then "light-value" else "dark-value";
darkTheme = config.stylix.polarity == "dark";
color-scheme = "prefer-${config.stylix.polarity}";
```

Use `force = true` on `home.file` entries for declaratively-managed config files that tools may otherwise overwrite.

### Impermanence / persistence

`nixos-modules/custom/persist.nix` and `home-modules/core/persist.nix` wrap the **impermanence** flake. Both expose a `custom.persistence.{files,directories}` option that any module can append to; the NixOS module collects everything and splits per-user home paths into the home-manager impermanence module, with the rest going to `environment.persistence.<persistDir>`. The home module also strips `home.homeDirectory` prefixes automatically. Add persistent paths from any module with `custom.persistence.directories = [ ... ];`.

### Custom packages

`pkgs/default.nix` returns `{ inherit myPkgs; } // myPkgs`, so the overlay both exposes `pkgs.myPkgs.*` (for `flake.packages`) and merges every package directly into `pkgs` — call them as `pkgs.<name>` in modules.

Only add a package to `pkgs/` when it needs **global scope** — i.e. it must be reachable as `pkgs.<name>` across the whole repo.

### Package versions

There is no `unstable` input and no `pkgs/pin` tree — both were replaced by **nixpkgs-multiverse** (`multiverse` flake input), exposed on the pkgs set as `pkgs.mv` by `pkgs/branches.nix`. The base `nixpkgs` input is the `nixos-26.05` channel tarball.

- `pkgs.mv.version "<attr>" "<version>"` — a specific historical version (e.g. `pkgs.mv.version "easyeffects" "7.2.5"`)
- `pkgs.mv.tip.<attr>` — the attr as of the newest indexed nixpkgs revision (what `pkgs-unstable` used to provide)
- `pkgs.mv.latest.<attr>` — the newest version of that attr, whichever revision shipped it

Every indexed attribute/version pair is browsable at <https://nixmultiverse.com/>.

## Working Conventions

### Commits

Always use the `/commit` skill when committing in this repo.

### Agent policy

Some commands are blocked by policy, not preference: don't run `home-manager switch` — use `ldp` to build and switch.

### Querying machine config

Prefer `nix eval` over reading source files to answer questions about configuration. Examples:

```sh
# What packages are installed for a user?
nix eval .#homeConfigurations."reed@nixos-desktop".config.home.packages --apply 'ps: map (p: p.name) ps' --json

# Is a NixOS option enabled?
nix eval .#nixosConfigurations.nixos-desktop.config.services.openssh.enable

# What value does an option have?
nix eval .#nixosConfigurations.nixos-desktop.config.networking.hostName
```

For user config, query the per-host override (e.g.
`homeConfigurations."reed@nixos-desktop"`), not the bare
`homeConfigurations.reed` — the latter is only a minimal standalone base
(4 home.file entries), while the real per-machine config lives in the
`<user>@<host>` variants.

This gives the evaluated, final config rather than requiring you to trace through module imports manually.

**Batch related lookups in one call.** Each `nix eval` invocation pays a ~0.5 s flake-setup + module-instantiation cost that the on-disk eval cache does not amortize. When you need several attrs from the same configuration, compose them into a single `--apply` instead of running N separate evals (~2× faster for 3 attrs, ~4× for 15):

```sh
nix eval --json .#nixosConfigurations.nixos-desktop --apply '{ config, ... }: {
  hostName = config.networking.hostName;
  openssh  = config.services.openssh.enable;
  pkgCount = builtins.length config.environment.systemPackages;
}'
```

The same pattern works against `homeConfigurations.<user>` — destructure with `{ config, ... }:` and pull as many leaves as you need in one shot.

### Nix

- Don't hoist `let` bindings for single-use derivations; pass inline and let Nix string-coerce the store path (`builtins.toString` is not needed).
- Never use the `rec` keyword, and never start a module with a bare `_:` argument — pre-commit hooks reject both. Use a `let` binding (or `pkgs.writeShellApplication` with `(self: { ... })`) instead of `rec`.
- Patches go in `pkgs/patches/<package-name>/`; reference as `../patches/<package-name>/...` from `default.nix`.
- Non-trivial shell scripts in `writeShellApplication` (and similar) belong in a sibling `.sh` file: `text = builtins.readFile ./script.sh`.
- Never search all of `/nix/store/` with `find`, `grep`, or similar — it's enormous. Resolve store paths with `nix eval` instead (e.g. `nix eval nixpkgs#<package> --apply 'p: p.outPath' --raw`).

### Running tools

If a tool isn't installed, run it via Nix instead of reporting command-not-found or asking the user to install it: `nix run nixpkgs#<package> -- <args>` or `nix-shell -p <package> --run '<command>'`.

## Memory

This file serves as the persistent memory for this project. When you learn something worth remembering — a correction, a confirmed approach, a project convention — write it back here under the relevant section, exactly as you would write an auto-memory entry.

## pi agent extensions (custom-ui tool UI)

The pi extensions in `home-modules/extra/ai/pi/plugins/` implement a Claude Code-style tool UI. Non-obvious constraints learned building it:

- **Tool-name ownership is exclusive**: only one extension may `registerTool` a given name (pi errors on conflicts). `bash` is owned by `nix-comma.ts` (spawn hook); `custom-ui.ts` owns everything else, including `read` with inline kitty-placeholder image rendering (functionality merged from the former image-history.ts — no separate extension anymore). Rendering slots are shared via `plugins/lib/custom-ui.ts` (a `lib/` plugin kind — not auto-loaded by pi, but installed to `~/.pi/agent/extensions/lib/` for `./lib/…` relative imports). User messages also render through custom-ui: zentui-style "compact" look (accent rail + body, no box) via a Symbol.for-guarded `UserMessageComponent.prototype.render` patch that reuses the component's own Markdown child (so markdown transformers keep applying); theme comes from `ctx.ui` captured at `session_start` (`.theme` is a live getter).
- **Shared state must live on `globalThis`**: each extension may get its own module instance of the lib, so cross-extension state (e.g. tool batch tracking) uses a `globalThis` singleton, not module scope.
- **Never call `context.invalidate()` synchronously from a render slot**: it re-enters the row's `updateDisplay()` mid-rebuild and duplicates every component. Defer with `setTimeout(0)` (see `settleStatus`).
- **Renderer exceptions are silent**: pi catches slot exceptions and swaps in its fallback renderer (raw truncated output). A TDZ/ReferenceError in a renderer looks like "glances disappeared". `/tmp`-style replay harness: run a real session JSONL through `scanToolGroupsFromHistory` + renderers with a mock theme and count throws.
- **Typecheck the plugins, take TS2304 seriously**: strict `tsc --noEmit` over the plugins dir finds missing imports that jiti only surfaces as runtime ReferenceErrors which pi then swallows (renderer fallback / event-handler error log). When image-history.ts was merged into custom-ui.ts, six dropped imports (node:crypto/fs/url + lib helpers) silently killed inline image embedding, the history-entry fallback, and read-row rendering — the TS2304s were the only signal. Setup: the plugins dir has a tracked `tsconfig.json` (strict, NodeNext) and needs an **untracked real `node_modules/` dir** of symlinks (a symlinked `node_modules` itself fails — /nix/store is read-only): every entry of pi's bundled `node_modules/*`, plus `@earendil-works/pi-coding-agent` → the monorepo root and `@earendil-works/pi-tui` → pi's bundled `node_modules/@earendil-works/pi-tui` (the store monorepo has no `packages/` dir). Baseline is **45 pre-existing strict errors** — always diff against a `git stash` baseline; only new errors count. `smoke.mjs` (tracked) drives the grouping state machine + header renderers headlessly under `node --experimental-strip-types` — the working-tree lib imports run without pi, so renderer changes can be asserted without a live TUI.
- **Debugging pi's TUI headlessly**: `script -m advanced -qec "TERM=xterm-256color pi …" --log-timing t.log io.log` gives byte-level I/O timing of a real pi instance. Limits: a dumb pty never answers pi's kitty-keyboard negotiation, so app-action keys (ctrl+t etc.) never fire in the harness — only TUI-global keys (PageUp) and plain typing work; keybinding bugs need the real terminal. Exit dumps produce huge output bursts easily mistaken for live repaints — bucket the timing log.
- **One Thinking indicator (unification rule)**: three surfaces used to show "Thinking" at once — pi's native loader row, the thinking-fold streaming row, the custom-ui batch header. Rule now (v3): the batch header ALWAYS animates for the whole batch run; during batch thinking the fold row streams label-less (fork labelFor returns "" while `__piCustomUiAnim.batchOpen` — just reasoning preview beneath the header); fresh-thinking rows (no batch) get the full animated label ({ frame, batchOpen, spinnerFrame, inProgressDot, streamingLabel, tick } — shared clock; base16 SGR colors, no Theme needed). pi's loader is hidden on thinking_delta (`setWorkingVisible(false)`), restored on tool_call/text_delta/user message/agent_end — NOT on thinking_end (flicker between consecutive thinking blocks). The fork's streaming label must render through a pi-tui **Text**, not Markdown (raw SGR gets mangled); its timer runs at 80ms. The in-progress tool dot is dotsCircle (2-cell frames, spaces are anti-wiggle padding — do not trim) and solo batches tick so it animates.
- **Grouping rule**: consecutive tool calls form a batch; reasoning folds it visually (header + glance rows appear immediately) without closing it; visible assistant text, a user message, or `agent_end` closes it. **Narration exemption**: a message shaped thinking→text→toolCall keeps its fold row (visible text split the batch); its thinking is NOT stamped into the next batch header (custom-ui stamping + lib scan both skip narrated messages), and the fork's merge never strips a narrated message's fold — stripping a visible row was the missing-fold regression. While a batch's header is visible (folded, or ≥2 tools so the first row became "earlier"), `tickOpenBatch` animates it on an 80 ms timer (`ensureTick` in custom-ui.ts, restarted by tool_call/thinking_delta, self-stopping): dots spinner (random variant per batch, cli-spinners frames) + shimmer verb (pi-animations' shimmer recolored to a base0D→base0E→base0C stylix gradient over base04, raw truecolor SGR — beyond theme.fg) + zentui's verb catalog (deterministic per batchIndex). Settled batches render the old static `✻` header; restored ones too, so animation state needs no persistence. The shimmer palette is memoized — base16.json is read once per process, so /theme switches mid-session don't recolor it. Thinking durations (live and restored, via the pi-thinking-fold fork's `__piCustomUi*` globalThis maps) surface in the batch header. Extension notifications (`ctx.ui.notify` info level) fold into the open batch via the patched `showExtensionNotify`. Restored sessions rebuild batches via `scanToolGroupsFromHistory` on `session_start`.
- **pi-thinking-fold is a vendored fork** (`plugins/pi-thinking-fold/`, see its FORK.md): thinking lines fold into the custom-ui batch headers instead of rendering their own line. Its deviations from upstream are greppable (`__piCustomUi`).
- **`ctx.ui.notify` is not hookable** (no renderer/event); prefer folding notices into tool-result content (a `tool_result` handler may return replacement `content`) — see `nix-comma.ts`.
- **User messages and `!` shell commands share the compact look via prototype patches**: `installCompactUserMessages` rewrites `UserMessageComponent.prototype.render` (rail + base01 band, reusing the child Markdown); `installCompactBashCommands` (same file) post-processes `BashExecutionComponent.prototype.render` output instead of rebuilding it, so streaming/loader/truncation/expansion keep working — it drops the full-width `─` DynamicBorder rows (strip SGR, then `plain.length === width && /^─+$/`) and prefixes each line with a `theme.fg("warning", "▎")` rail (warning = base0A yellow under the stylix-generated theme in pi/default.nix) over `base16Bg("base01")`. `BashExecutionComponent` is exported from the package root and used for both live runs and history rebuilds, so one prototype patch covers both; `excludeFromContext` (`!!`) is not observable from render output, so `!` and `!!` now render identically. While a command runs, the patch also retargets the `Loader` on first render (found via `contentContainer.children` + `instanceof`, one-shot per instance in a WeakMap): its `frames`/`spinnerColorFn`/`messageColorFn` are TS-private but plain runtime fields — a plain structural view must be used, since intersecting with `Loader` (which declares them private) collapses the type to `never`. The loader's own 80ms tick drives both the random cli-spinners dots variant and the "Running…" shimmer (yellow→orange→red, base0A→09→08 — `shimmerFrame` in the lib now takes optional gradient stops, default remains the batch header's cyan/purple), no timer of our own. Spacing is normalized in the same post-process: output ending in `\n` leaves a blank `outputLines` entry that stacks with the loader/status row's own leading blank, so blank runs are collapsed to one and a single trailing blank is appended — the spinner/status row ends up with one blank line before and after.
- **Consumed input suppresses repaint**: the TUI input loop `return`s on `{ consume: true }` from `onTerminalInput` listeners BEFORE the `requestImmediateRender()` that follows every keypress, and the UI context exposes no requestRender. pi-thinking-fold consumes ctrl+t and mutates components, so folds apply only on the next key. Fix: `thinking-fold-redraw.ts` shim — global extensions load before configured packages (loader discovery order: project `.pi/extensions/` → `~/.pi/agent/extensions/` → settings.json packages), so its listener sees ctrl+t first and defers a render via a TUI handle captured from a zero-line `setWidget` factory (same capture trick as the statusline footer; widgets, unlike footers, can be additive).
- `genericSlots(label, argOf)` in the lib gives any tool the full treatment in ~3 lines; `pi.getAllTools()` exposes no `execute`, so third-party/MCP tools cannot be re-rendered generically.
