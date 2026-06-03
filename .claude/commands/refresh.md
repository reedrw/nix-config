Scan changes made to this repo since CLAUDE.md was last updated, and update CLAUDE.md if anything notable warrants documentation.

## Step 1 — Find the baseline

```sh
git log --follow -1 --format="%H %ai" .claude/CLAUDE.md
```

This gives the commit hash and date of the last CLAUDE.md change. Use that hash as the baseline.

## Step 2 — Enumerate changes since baseline

```sh
git log <baseline-hash>..HEAD --oneline
git diff <baseline-hash>..HEAD --stat
```

Read the full diff for files that look architecturally significant:

```sh
git diff <baseline-hash>..HEAD -- <file>
```

Focus your reading on:
- New directories or modules added under `nixos-modules/`, `home-modules/`, or `pkgs/`
- Changes to `flake.nix`, `repo/default.nix`, `repo/extraEzModules.nix`
- New or renamed helpers in `pkgs/functions.nix`
- New custom packages under `pkgs/<tool>/`
- New overlays or overlay ordering changes in `pkgs/overlays.nix`
- Changes to the impermanence / persistence module interface
- New flake inputs
- New `ldp` flags or `install.sh` behavior

## Step 3 — Decide what's notable

A change is notable if a future reader of CLAUDE.md would benefit from knowing it exists. Rough tests:

- **Add:** New module category or subdirectory, new pkgs helper, new custom package, new flake input that affects how modules are written, meaningful new option or convention, new `ldp` flag.
- **Skip:** Routine config tweaks (enabling a service, changing a setting value), package version bumps, one-host-only quirks with no reuse implications, things already documented, cosmetic renames.

If there are no notable changes, stop here and tell the user "No notable changes since CLAUDE.md was last updated."

## Step 4 — Update CLAUDE.md

Read `.claude/CLAUDE.md` in full, then make targeted edits:
- Add new helpers to the "Useful helpers from `pkgs/functions.nix`" list.
- Add new packages to the "Custom packages" section or the directory layout tree.
- Add new modules to the directory layout tree.
- Add new flake inputs or structural changes under "Architecture".
- Update existing entries rather than duplicating them.
- Do not add entries for individual config values or host-specific settings.
- Keep the writing style terse and consistent with the existing file.

After editing, briefly summarize what you added or changed and why.
