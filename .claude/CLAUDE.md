# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Key Commands

Use the `/ldp` skill to build, switch, or boot configurations.

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
- `repo/git-hooks.nix` — pre-commit hooks (statix, deadnix, shellcheck, trim-whitespace) via `git-hooks-nix`; injected into the dev shell automatically
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

home-configurations/    # Per-user (and per-user@host) home-manager entry points
  reed.nix
  reed@nixos-desktop/
  reed@nixos-t480/
  ...

nixos-modules/          # Reusable NixOS modules — each category has a default.nix that imports its siblings
  core/                 # Always-on: nix, kernel, zsh, home-manager integration, styling, run0
  custom/               # Site-specific: persist (impermanence), snapper, steam, nix-ssh-serve, boot/, games/
  extra/                # Opt-in: sshd, ollama, logitech, actualbudget, android/
  graphical/            # GUI: fonts, opengl, sound, xserver, gnome
  networking/           # autoupdate, networking defaults
  virtualization/
  users/                # System user definitions (cherry-picked via ezModules'.users.<name>)

home-modules/           # Reusable home-manager modules — same category-default.nix pattern
  core/                 # nvim, zsh, ssh, persist, stylix styling, nixpkgs config, functions, comma
  extra/                # git, mullvad, gnupg, claude-code, proc, base
  graphical/            # kitty, firefox, flameshot, obs, bitwarden, fontconfig
  games/
  media/                # mpd, zathura
  social/               # signal, telegram
  filesharing/

pkgs/                   # Custom packages, overlays, and pkgs-extension helpers
  overlays.nix          # Lists the overlays composed in order: branches, default, pin, alias, functions
  default.nix           # myPkgs attrset → inherited and spread via `// myPkgs` so packages are accessible as `pkgs.<name>`
  config.nix            # nixpkgs config (allowUnfree, packageOverrides exposing `flake` legacy access)
  branches.nix          # Adds `nur` and `pkgs-unstable` to the pkgs set
  alias.nix             # Overrides specific upstream packages (patches for adwsteamgtk, jellyfin-mpv-shim, lix, updog, etc.)
  functions.nix         # Helper functions added to pkgs set (see below)
  pin/                  # Pinned package versions
  patches/              # Local patch files used by alias.nix overrides
  <tool>/               # One directory per custom package/script (ldp, gc, fluxer, jdownloader, mountiso, unscene, update-all, wheel-wizard, persist-path-manager)
```

### Useful helpers from `pkgs/functions.nix`

These are added to the pkgs set, so `pkgs.<helper>` works anywhere:

- `pkgs.mullvadExclude pkg` — wrap `pkg` so its main binary runs via `mullvad-exclude` (no-op when wrapper isn't present)
- `pkgs.wrapEnv pkg { VAR = "val"; }` — wrap a package's main program with exported env vars
- `pkgs.wrapPackage pkg (binPath: "shell script body")` — generic wrapper around a package's main program
- `pkgs.aliasToPackage { name1 = "shell body"; name2 = "..."; }` — turn a set of one-liners into a single derivation containing those binaries (used for "global aliases")
- `pkgs.writeNixShellScript name text` — promote a `nix-shell` shebang script to a `writeShellApplication` with runtime inputs parsed from the shebang. The script's **second line** must be `#! nix-shell -i bash -p <pkg1> <pkg2>` — packages listed there become the Nix `runtimeInputs`. Typical usage: `pkgs.writeNixShellScript "foo" (builtins.readFile ./foo.sh)`
- `pkgs.matchPackage "foo.bar.baz"` — resolve a dotted package path against the pkgs set

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

## Working Conventions

### Commits

Always use the `/commit` skill when committing in this repo.

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
- Patches go in `pkgs/patches/<package-name>/`; reference as `../patches/<package-name>/...` from `default.nix`.
- Non-trivial shell scripts in `writeShellApplication` (and similar) belong in a sibling `.sh` file: `text = builtins.readFile ./script.sh`.
- Never search all of `/nix/store/` with `find`, `grep`, or similar — it's enormous. Resolve store paths with `nix eval` instead (e.g. `nix eval nixpkgs#<package> --apply 'p: p.outPath' --raw`).

### Running tools

If a tool isn't installed, run it via Nix instead of reporting command-not-found or asking the user to install it: `nix run nixpkgs#<package> -- <args>` or `nix-shell -p <package> --run '<command>'`.

## Memory

This file serves as the persistent memory for this project. When you learn something worth remembering — a correction, a confirmed approach, a project convention — write it back here under the relevant section, exactly as you would write an auto-memory entry.
