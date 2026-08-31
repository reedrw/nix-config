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
Theming uses **Stylix** (`github:nix-community/stylix`) to expose color values for a chosen theme across the Nix module system. If asked to theme an application, treat the Stylix module as your source of truth for theming.

```nix
theme = if config.stylix.polarity == "light" then "light-value" else "dark-value";
darkTheme = config.stylix.polarity == "dark";
color-scheme = "prefer-${config.stylix.polarity}";
```

### Impermanence / persistence
`nixos-modules/custom/persist.nix` and `home-modules/core/persist.nix` wrap the **impermanence** flake. Both expose a `custom.persistence.{files,directories}` option that any module can append to; the NixOS module collects everything and splits per-user home paths into the home-manager impermanence module, with the rest going to `environment.persistence.<persistDir>`. The home module also strips `home.homeDirectory` prefixes automatically. Add persistent paths from any module with `custom.persistence.directories = [ ... ];`.

### Custom packages
`pkgs/default.nix` returns `{ inherit myPkgs; } // myPkgs`, so the overlay both exposes `pkgs.myPkgs.*` (for `flake.packages`) and merges every package directly into `pkgs` — call them as `pkgs.<name>` in modules.

Only add a package to `pkgs/` when it needs **global scope** — i.e. it must be reachable as `pkgs.<name>` across the whole repo.

### Package versions
To install or query specific versions of a package use the `multiverse` package set, exposed as `pkgs.mv`

- `pkgs.mv.version "<attr>" "<version>"` — a specific historical version (e.g. `pkgs.mv.version "easyeffects" "7.2.5"`)
- `pkgs.mv.tip.<attr>` — the attr as of the newest indexed nixpkgs revision (the version provided by `nixpkgs-unstable`)
- `pkgs.mv.latest.<attr>` — the newest version of that attr, whichever revision shipped it

Every indexed attribute/version pair is browsable at <https://nixmultiverse.com/>.

## Working Conventions

### Commits
Always use the `/commit` skill when committing in this repo.

### Build and switch with `ldp`
`ldp` is the one and only canonical way to deploy a config in this repo. Do not use `nixos-rebuild switch` or `home-manager switch`.

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

### Resolving a package's store path

```sh
nix eval nixpkgs#<package> --apply 'p: p.outPath' --raw
```

### Nix language bans (enforced by pre-commit hooks)

- **Never use `rec`** — the `no-rec` hook rejects it. Use a `let` binding (or
  `lib.fix` with a `(self: { ... })` closure) instead.
- **Never start a module with a bare `_:` argument** — the
  `no-empty-module-arg` hook rejects it. Destructure explicitly.

### Layout conventions
- **Patches** go in `pkgs/patches/<package-name>/`; reference them as
  `../patches/<package-name>/...` from `pkgs/*/default.nix` overrides.
- **Non-trivial shell scripts** in `writeShellApplication` (and similar)
  belong in a sibling `.sh` file, not an inline string:
  `text = builtins.readFile ./script.sh;`

## Memory
You may write niche knowledge into a skill `.agents/skills/`. If you believe that a change in this repo warrants updating AGENTS.md, show the user a draft and ask for approval.
