# VM staging — agent feedback loop

This directory wires up two NixOS QEMU VMs as a staging ground for
agents (or humans) working on the i3 → swayfx/noctalia migration:

| Host             | Session       | Purpose                                  |
| ---------------- | ------------- | ---------------------------------------- |
| `nixos-vm`       | i3 (current)  | Reference. Screenshot for comparison.    |
| `nixos-vm-sway`  | swayfx (stub) | Target. Where the migration work happens.|

Both VMs:
- Run **fully headless**: QEMU starts with `-display none`,
  `nohup`-detached, and `disown`-ed — no window pops up, no terminal
  is attached, and the VM survives the launching shell exiting.
  Screenshots come out via `vm-shoot.sh` (SSH + grim/maim), not a
  visible display.
- Auto-login as `reed` with password `vm`
- Run SSH on port 22 (forwarded to host `localhost:2222`)
- Share the host's `/nix/store` read-only — `nixos-rebuild test`
  inside the VM picks up host-side `git add`-ed changes instantly
- Use QEMU's `-snapshot` flag: every run starts from a clean disk
- Have screenshot tooling installed (`grim` for sway, `maim` for X11),
  wrapped behind a `vm-screenshot-grab` script that auto-detects the
  session

The full migration plan lives in `../i3-to-swayfx-migration.md`.

## Quick start

```sh
# 1. Boot the i3 reference VM, wait for it to come up, snap a baseline
./vm-staging/scripts/vm-run.sh nixos-vm
./vm-staging/scripts/vm-wait.sh 2222
./vm-staging/scripts/vm-shoot.sh 2222 ./vm-staging/screenshots/i3-reference.png
./vm-staging/scripts/vm-stop.sh nixos-vm

# 2. Edit home-modules/graphical/sessions/sway/ — the migration agent's
#    canvas — then `git add` the changes.

# 3. Boot the target VM, observe, iterate
./vm-staging/scripts/vm-run.sh nixos-vm-sway
./vm-staging/scripts/vm-wait.sh 2222
./vm-staging/scripts/vm-shoot.sh 2222 ./vm-staging/screenshots/sway-current.png
./vm-staging/scripts/vm-ssh.sh 2222 -- swaymsg -t get_tree | jq ...
./vm-staging/scripts/vm-stop.sh nixos-vm-sway
```

To run both VMs at once, set `VM_PORT=2223` on the second one (the
flag is honored by every script).

## What each script does

All scripts are plain `nix-shell`-shebanged bash — read them, modify
them, no Nix-build round-trip needed for changes.

| Script        | What it does                                                                |
| ------------- | --------------------------------------------------------------------------- |
| `vm-run.sh`   | `nix build` the VM, launch QEMU in the background, write a pidfile.         |
| `vm-stop.sh`  | SIGTERM the QEMU process (then SIGKILL if it sticks).                       |
| `vm-wait.sh`  | Block until SSH is up *and* a display server is running (~2-minute timeout).|
| `vm-ssh.sh`   | Wrap `ssh` with the right port/user/password for the staging VMs.           |
| `vm-shoot.sh` | Capture a screenshot to a local PNG. Validates PNG header before returning. |

Default env (overridable):

```
VM_PORT=2222         # host SSH forward
VM_MEM=4096          # MiB RAM
VM_CPUS=4
VM_DISPLAY=none      # default headless. only set this if you actively
                     #   want a QEMU window to pop up (e.g. "gtk")
VM_USER=reed
VM_PASSWORD=vm
```

## What the staging VMs intentionally don't do

The `custom.vmStaging.enable = true;` switch on these hosts forces off
anything that doesn't make sense in a snapshot VM, would slow boot, or
would lock out the agent. From `nixos-modules/custom/vm-staging.nix`:

- `services.btrfs.autoScrub` — VM has no btrfs subvols
- `services.fstrim` — ephemeral disk
- `systemd.services.lock-before-suspend` — would lock the agent out
- `pkgs.lockProgram` — overlay-replaced with a no-op script
- `users.mutableUsers` — forced true so the staging password applies
- `security.sudo.wheelNeedsPassword` — forced false (passwordless sudo
  inside the VM for `reed`)

If you want any of these back in the staging environment for a specific
test, override per-host in the relevant `configuration.nix`.

## Typical agent loop (for the swayfx migration)

```sh
# Setup: capture the i3 baseline once
./vm-staging/scripts/vm-run.sh nixos-vm
./vm-staging/scripts/vm-wait.sh 2222
./vm-staging/scripts/vm-shoot.sh 2222 ./vm-staging/screenshots/i3-reference.png
./vm-staging/scripts/vm-stop.sh nixos-vm

# Each iteration:
#   1. Edit home-modules/graphical/sessions/sway/ (and friends)
#   2. git add the modified files (flake won't see them otherwise)
#   3. Launch the target VM
#   4. Compare its screenshot to i3-reference.png
#   5. SSH in to inspect state, run swaymsg queries, etc.
#   6. Stop the VM. Repeat.
./vm-staging/scripts/vm-run.sh nixos-vm-sway
./vm-staging/scripts/vm-wait.sh 2222
./vm-staging/scripts/vm-shoot.sh 2222 ./vm-staging/screenshots/sway-current.png
./vm-staging/scripts/vm-ssh.sh 2222 -- swaymsg -t get_outputs
./vm-staging/scripts/vm-stop.sh nixos-vm-sway
```

The screenshots live under `./vm-staging/screenshots/` and are
git-tracked so progress is visible in PRs.

## Notes for agents

- **Always `git add` before `nix build` / `vm-run`.** Flakes only see
  staged files. Edits to already-tracked files don't need re-staging.
- **Headless by default.** `VM_DISPLAY=none` (the default) means no
  QEMU window pops up; the VM runs entirely in the background via
  `nohup ... & disown`. Visual inspection happens via `vm-shoot.sh`
  (over SSH). Only set `VM_DISPLAY=gtk` if you actively want a
  window — and only if you're at a graphical session that can host
  one (won't work over plain SSH).
- **Snapshot mode wipes state on shutdown.** If you want to keep
  something across runs, write it to the host filesystem (the VM's
  `/nix/store` is the host's) or persist via the impermanence
  module's existing options.
- **The sway session module** (`home-modules/graphical/sessions/sway/
  default.nix`) is a deliberate stub. It boots into a default swayfx
  session with no keybindings, no bar, no nothing. That's intentional —
  it's the canvas to fill in per the migration plan.
- **Software rendering.** The VMs run swayfx/X11 in QEMU's software
  rasterizer; performance is bad but correctness is fine. Compositor
  effects (blur, shadows) will render — just slowly.
- **First boot is slow.** First `vm-run.sh` invocation builds the VM
  closure (~10 min on a cold cache). Subsequent runs reuse it.
