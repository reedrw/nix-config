---
name: stage
description: Boot the nixos-vm staging VM, capture a screenshot, and tear it
  down. Use whenever a change is expected to alter on-screen output — sway
  config, waybar, rofi, swaync, kitty, stylix theming, new graphical
  home-modules or nixos-modules/graphical/, fontconfig. SKIP for refactors,
  comments, renames, option-only changes, and non-graphical work — the VM
  build takes time and the screenshot won't reveal anything.
---

# stage

Validates UI changes by booting `nixos-vm` headlessly, capturing a screenshot
over SSH, and stopping the VM.

## Before invoking

1. **Stage your changes**: `git add` modified/new files. Nix flakes read only
   git-tracked content — unstaged edits are invisible to the VM build.
2. **Know what you expect to see.** If you can't articulate the visible delta,
   the screenshot won't tell you anything.

## Invocation

```sh
./repo/stage/stage.sh [output.png]
```

- No arg → ephemeral screenshot at `$XDG_RUNTIME_DIR/stage/screenshots/<timestamp>.png`
- Explicit path inside the repo → persistent PR artifact (commit it intentionally)

## After invocation

Read the screenshot. State what you see, not what you hoped for. If the change
isn't visible:
- Check files were staged (`git diff --cached`)
- Check the module is actually imported
- Inspect the running session: `./repo/stage/ssh.sh 2222 -- systemctl --user status waybar`

## Cost

~30 s warm build + 20 s boot + 5 s shoot. Cold cache: tens of minutes.
Don't invoke for plumbing changes. Don't invoke speculatively.

## Primitive scripts (for manual debug)

All under `repo/stage/`: `run.sh`, `wait.sh`, `shoot.sh`, `ssh.sh`, `stop.sh`.
`stage.sh` composes them with auto-cleanup on exit.
