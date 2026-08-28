Run `ldp $ARGUMENTS`.

**Targets:**
- NixOS hosts: `nixos-desktop`, `nixos-t480`, `nixos-t400`, `nixos-vm`, `nixos-iso`, plus `<host>-no-home-manager` variants of desktop/t480/t400
- Home-manager: `reed`, `nixos`, `reed@nixos-desktop`, `reed@nixos-t480`, `reed@nixos-t400`, `reed@nixos-vm`

(`ldp --list-outputs` prints the authoritative list.)

**Common flags:**
```sh
ldp --build <target>     # build without switching
ldp --switch [hostname]  # build and switch (defaults to $(hostname))
ldp --boot [hostname]    # build and set boot entry
ldp --list-outputs       # list all flake outputs
```

A bare `ldp` builds and switches the current hostname — that's the normal case. Use `ldp --build <target>` to build other hosts without switching.

**Important:** New files must be `git add`-ed before running ldp — Nix flakes only see tracked files.

If `$ARGUMENTS` contains ` -- `, treat everything before ` -- ` as the ldp flags and everything after as additional instructions to execute after a successful build.

**Error loop:** If ldp produces evaluation or build errors, investigate the error, fix it, and rerun. Repeat until the build succeeds or you hit an error that genuinely requires user input. Do not exit the skill with a failing build.

After following any additional instructions (from ` -- `), always rerun the original ldp command to confirm the final build succeeds.

**Locating the repo:** `ldp --switch/--boot` bakes the repo path into the binary at build time by reading `nixos-configurations/<hostname>/.flake-path`. On a fresh clone where that file doesn't exist, ldp falls back to `$(pwd)` and must be run from the repo root.
