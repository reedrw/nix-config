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

- No arg → screenshot at `repo/stage/screenshots/<timestamp>.png` (gitignored, persists for review)
- Explicit path → write to that location instead

## After invocation

Read the screenshot. State what you see, not what you hoped for. Then show the
user the screenshot path and **wait for explicit sign-off** before proceeding to
commit. Do not commit until the user confirms the screenshot looks correct.

If the change isn't visible:
- Check files were staged (`git diff --cached`)
- Check the module is actually imported
- Inspect the running session: `./repo/stage/ssh.sh 2222 -- systemctl --user status waybar`

## Cost

~30 s warm build + 20 s boot + 5 s shoot. Cold cache: tens of minutes.
Don't invoke for plumbing changes. Don't invoke speculatively.

## Primitive scripts (for manual debug and interactive sessions)

All under `repo/stage/`: `run.sh`, `wait.sh`, `shoot.sh`, `ssh.sh`, `sendkey.sh`,
`stop.sh`. `stage.sh` composes run+wait+shoot+stop with auto-cleanup on exit.

### Keeping the VM alive across multiple checks

When validating a keybind, a service, or anything that needs more than a
single shot, drive the primitives by hand instead of calling `stage.sh` — the
pidfile in `$XDG_RUNTIME_DIR/stage/` persists between invocations:

```sh
repo/stage/run.sh                          # boot once, returns immediately
repo/stage/wait.sh 2222                    # block until sway is up
repo/stage/ssh.sh 2222 -- wpctl get-volume @DEFAULT_AUDIO_SINK@   # baseline
repo/stage/sendkey.sh volumeup             # simulate XF86AudioRaiseVolume
repo/stage/ssh.sh 2222 -- wpctl get-volume @DEFAULT_AUDIO_SINK@   # after
repo/stage/shoot.sh 2222 /tmp/after.png    # optional
repo/stage/stop.sh                         # when done
```

`run.sh` exits non-zero if the VM is already up, so re-running it is safe —
treat it as idempotent boot.

### sendkey.sh

Injects QEMU monitor `sendkey` events. Sway sees them as real libinput key
events, so XF86Audio*/XF86MonBrightness* keybinds fire end-to-end:

```sh
repo/stage/sendkey.sh volumeup           # one press
repo/stage/sendkey.sh volumeup volumeup  # two presses
repo/stage/sendkey.sh ctrl-alt-t         # chord
```

Common identifiers: `volumeup`, `volumedown`, `audiomute`, `audionext`,
`audioprev`, `audioplay`, `audiostop`. Anything QEMU accepts in HMP works.

Requires the monitor socket, which `run.sh` sets up at
`$XDG_RUNTIME_DIR/stage/nixos-vm.monitor.sock`.
