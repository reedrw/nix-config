# i3wm → swayfx Migration Assessment

Audit of `nix-config` (commit `ea8f26d5`, branch `main`) to assess what it
would take to swap the i3wm/X11 desktop for a swayfx/Wayland session.

## TL;DR

**Difficulty: Moderate.** Roughly 2–4 focused days of porting, plus a tail of
small fit-and-finish work as edge cases surface. The repo is in unusually
good shape for this kind of move:

- `home-modules/graphical/sessions/` is already partitioned per-session
  (`i3/`, `gnome/`), so the migration is "add a `sway/` peer" rather than
  rewriting `i3/` in place. You can ship the change behind a session toggle.
- Stylix already provides the matching upstream targets — verified by
  `nix eval` on the live config: `sway`, `noctalia-shell`, and `rofi`
  are all available alongside the `i3`/`polybar`/`feh` ones currently
  in use. Theming carries over for free.
- The shell stack collapses dramatically. **noctalia-shell** replaces
  polybar **and** dunst **and** rofi (for general app launching) **and**
  swaylock **and** swaybg **and** swayidle **and** cliphist in a single
  Quickshell-based binary — bar, notifications, launcher, lock,
  wallpaper, clipboard manager, control center, idle management,
  custom script widgets. Noctalia explicitly supports sway in its
  compositor list.
- The previous experiment is still in the tree: `nixos-modules/graphical/
  xserver.nix:5-10` has a commented-out `programs.sway` block with the
  swayfx package override and `passthru.providedSessions = [ "sway" ]`.
- The GNOME session already runs Wayland — `home-modules/graphical/
  sessions/gnome/default.nix:18` enables `xwayland-satellite` —
  so the Wayland plumbing (xdg-portal, pipewire screencast, GDM session
  switching) is partially exercised.
- AMD desktop (`amdgpu`) and Intel T480 iGPU both have first-class
  Wayland support; kernel `7.0.10-zen1` is well past any Wayland minimum.

The painful parts are the **shell-script surface** (≈10 scripts under
`home-modules/graphical/sessions/i3/config/scripts/` and
`polybar/`) and a handful of behavioral quirks (Steam/Vesktop minimize-
to-tray workaround, X11-only ffmpeg recording) that don't have
drop-in Wayland equivalents.

The **largest single behavioral break** is the saved-workspace
JSON layout system used by `load-layouts.sh` and `select-term.sh`:
sway has explicitly closed this as wontfix
([swaywm/sway#1005](https://github.com/swaywm/sway/issues/1005)),
so `append_layout`'s placeholder/swallow model is a dead end on
sway and the workflow has to be redesigned around "launch and move"
rather than "place and swallow." Details in pain point #2.

## Hosts in scope

Cross-referenced from `nixosConfigurations.*` (`nix eval`):

| Host          | Display server today                | Wayland readiness                                                                                   |
| ------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------- |
| nixos-desktop | X11 (`amdgpu`), GDM, xsession       | Best target. amdgpu = mature Wayland support.                                                       |
| nixos-t480    | X11 (Intel iGPU), GDM, xsession     | Same story as desktop. Intel iGPU works on Wayland; `services.libinput` config carries over.        |
| nixos-vm      | X11 (modesetting), xsession         | QXL/virtio-gpu works with sway, but performance is the constraint, not protocol. Good test bed.     |
| nixos-t400    | Headless (no `services.xserver`)    | Out of scope — `home-configurations/reed@nixos-t400.nix` imports only `core`/`extra`.               |
| nixos-iso     | Installer                           | Out of scope.                                                                                       |

The home-manager session is wired per-host via
`home-configurations/reed@<host>/default.nix` — both `nixos-desktop`
and `nixos-t480` import `ezModules.graphical`, so a `sessions/sway/`
peer added to that category will automatically be available on both.

## The i3 configuration surface

What lives under `home-modules/graphical/sessions/i3/` and what
happens to it under swayfx:

### Direct replacements (1:1, mostly mechanical)

| i3 file / option                                  | swayfx target                                       | Notes                                                                                                                                                                  |
| ------------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `xsession.windowManager.i3` (config/default.nix)  | `wayland.windowManager.sway` (HM)                   | Same option shape — `bars`, `gaps`, `fonts`, `window`, `floating`, `modifier`, `terminal`, `startup`. The `commandForWindows` helper translates directly.               |
| `keybinds.nix`                                    | sway keybindings                                    | Mod1/Mod4 names unchanged. `i3-msg` → `swaymsg`. `XF86*` keysyms unchanged.                                                                                              |
| `services.dunst` (i3/dunst.nix)                   | drop — noctalia handles notifications               | Noctalia provides toast notifications and notification history. The stylix `dunst` target turns off; `noctalia-shell` turns on. The notify-send-based scripts (`brightness.sh`, `volume.sh`, `calnotify.sh`, claude-code hooks) keep working unchanged because noctalia speaks the standard `org.freedesktop.Notifications` D-Bus interface. |
| `xdgApps.nix`                                     | unchanged                                           | Just MIME associations.                                                                                                                                                |
| `services.flameshot` (`graphical/flameshot.nix`)  | flameshot (partial) **or** grim+slurp+swappy/satty  | Flameshot's Wayland support is incomplete (selection works, drawing tools and "pin" feature wobble). Most sway users replace it.                                       |
| `pkgs.lockProgram = i3lock-fancy` (alias.nix:30)  | noctalia's built-in lock screen                     | The `lockProgram` alias becomes a wrapper that invokes `noctalia-shell` lock IPC (whatever the noctalia CLI for "lock now" turns out to be). Every call site picks it up: `xserver.nix:40`, `i3/default.nix:73`, `i3/keybinds.nix:19`. If noctalia's lock proves too limited, fall back to `swaylock-effects`. |
| `xresources.path = "$XDG_DATA_HOME/X11/..."`      | drop                                                | No Xresources under sway.                                                                                                                                              |
| `xsession.{enable,profilePath,scriptPath}`        | drop                                                | sway is launched via `sway` from the display manager; no xprofile.                                                                                                     |
| `services.picom` (i3/picom.nix)                   | drop entirely                                       | swayfx has built-in shadow, blur, corner-radius, fade. Shadow-exclude entries for `i3-frame`/`Polybar` become moot.                                                     |
| `polybar` (i3/polybar/default.nix + 4 scripts)    | noctalia bar                                        | Noctalia ships multi-monitor bars with workspaces, taskbar, system tray, media, network, battery, brightness, weather, clipboard, and **custom script-backed widgets** — the four polybar scripts get re-wired as those. Stylix has a `noctalia-shell` target so the base16 colors apply automatically. |
| `rofi` (`programs.rofi.package = rofi`)           | noctalia launcher (primary), `rofi-wayland` (fallback for `rofi-comma.sh`) | Noctalia includes an integrated launcher with libqalculate-backed calc. The `Mod+Shift+;` rofimoji binding and the `Sup+space` rofi-comma binding are the questions: rofimoji can likely move to noctalia's launcher or a small custom widget; `rofi-comma.sh` is rofi-specific scripted-mode UX, so keeping `rofi-wayland` *just* for that one binding is the path of least resistance. |
| `feh --bg-fill` for wallpaper                     | noctalia wallpaper manager                          | Noctalia's wallpaper widget points at an image path. The `wallpaper-colored` derivation that lutgen-recolors the wallpaper is unchanged — just hand its output store path to noctalia instead of `feh`. The `swaybg` step in the original plan disappears.        |
| `xclip` / `xsel` shell aliases (`c`, `pbcopy/paste`) | `wl-copy` / `wl-paste`                          | Add a `wl-clipboard` runtime dep; the alias block in `i3/config/default.nix:95-106` becomes a sway-conditional file. (Noctalia handles GUI clipboard history; `wl-clipboard` is still what shell scripts call.) |
| `autotiling-rs`                                   | unchanged                                           | nixpkgs description literally reads "Autotiling for sway (and possibly i3)" — sway is the primary target. Same systemd user unit, just under the sway session.         |
| `swayidle` (would-have-been)                      | noctalia idle management                            | Skipped entirely — noctalia handles idle directly via Wayland idle protocols. Driven from its config rather than a separate daemon. |

### Picom → swayfx settings translation

Current picom config (`i3/picom.nix`) — what swayfx gives you:

| picom setting                                         | swayfx equivalent                                                |
| ----------------------------------------------------- | ---------------------------------------------------------------- |
| `shadow = true; shadow-opacity = 0.6; shadow-radius = 20` | `shadows enable`, `shadow_color`, `shadow_blur_radius`           |
| `corner-radius = 10`                                  | `corner_radius 10`                                               |
| `fade = true; fadeDelta = 3`                          | `default_dim_inactive` + `for_window` opacity rules (sway/swayfx) |
| `opacity-rule = [ "10:... STICKY ..." ]`              | `for_window [...] opacity 0.1` (sway syntax)                     |
| `shadowExclude` (Polybar, i3-frame, slop, KDE menus)  | no equivalent needed — most are gone after migration              |

The picom `rounded-corners-exclude = [ "class_g = 'i3-frame'" ]`
rule exists because i3's split-frame indicator is its own X11 window.
sway draws split indicators internally, so the rule is moot.

### Scripts (the long tail)

In `home-modules/graphical/sessions/i3/config/scripts/`:

| Script                | X11 tooling                              | Wayland port                                                                                                                                                                                                                                                                                |
| --------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `brightness.sh`       | `brightnessctl`, `bc`, `dunstify`        | Unchanged.                                                                                                                                                                                                                                                                                  |
| `volume.sh`           | `wpctl`, `gsettings`, `pactl`, `dunstify` | Unchanged.                                                                                                                                                                                                                                                                                  |
| `dwebp-serv.sh`       | `inotifywait`, `dwebp`                   | Unchanged.                                                                                                                                                                                                                                                                                  |
| `droidcam-fix.sh`     | `v4l2loopback-ctl`                       | Unchanged.                                                                                                                                                                                                                                                                                  |
| `clipboard-clean.sh`  | `xclip`, `clipnotify`                    | Port to `wl-paste --watch` + `wl-copy`. Fairly mechanical — the script body is short.                                                                                                                                                                                                       |
| `record.sh`           | `slop`, `ffmpeg -f x11grab`              | Replace with `wf-recorder -g "$(slurp)" -f ...mp4`. `wf-recorder` is wlroots-native and supports the same pause/SIGINT model.                                                                                                                                                              |
| `select-term.sh`      | `slop`, `i3-msg append_layout`           | **Architectural rework.** `swaymsg append_layout` exists but the placeholder/swallow mechanism is unreliable by upstream design (see "Saved workspace layouts" below). Realistic port: `slurp` for selection, then `swaymsg [app_id="kitty"] mark --add float`, `swaymsg for_window [con_mark="float"] floating enable, move position <x> <y>, resize set <w> <h>`, then `kitty -T float`. Different model, similar UX.       |
| `load-layouts.sh`     | `i3-msg workspace`, `i3-msg append_layout` | **Architectural rework.** Same root cause — see "Saved workspace layouts" below. Practical replacement is the inverse of i3's flow: launch apps first, then move them with `swaymsg [app_id=...] move to workspace N`, optionally using `swayrst` or a custom GET_TREE-based script.       |
| `killwrapper.sh`      | `xdotool`, `xwininfo`, `pgrep -f`        | **Hardest port.** Walks the X11 window tree to count "how many Vesktop windows are open?" so that closing the last one *kills* the process rather than minimizing to the tray. Wayland clients have no global window enumeration; you can use `swaymsg -t get_tree | jq ...` for sway clients only, and `pgrep`/`pidof` as a fallback. Doable but needs rewriting from scratch. **Easier:** turn off "minimize to tray" in Vesktop/Steam and delete the workaround.                                                                                                                              |
| `mpv-dnd.sh`          | `xdotool getactivewindow`, `xprop _NET_WM_PID` | Replace with `swaymsg -t subscribe '["window"]'` + jq to react to focus changes. The "stop signal to Telegram/Discord while mpv is foregrounded" idea translates fine; the implementation does not.                                                                                       |
| `toggle-touchpad.sh`  | `xinput`                                 | `swaymsg input <id> events toggle`. The Synaptics/Touchpad detection logic disappears — sway already classifies inputs.                                                                                                                                                                     |
| `keybinds.sh`         | `xmodmap`, `xset r rate`, `xinput natural-scrolling`, `solaar-cli` | Splits across surfaces: key repeat → sway `input * { repeat_delay; repeat_rate }`; CapsLock→Ctrl → `xkb_options ctrl:nocaps`; natural scrolling → `input <type:touchpad> { natural_scroll enabled }`. The **Shift+Esc → tilde** and **PageUp/Down → Forward/Back** remaps don't have a sway-native equivalent — those need `keyd`, `kanata`, or interception-tools at the kernel layer. The `solaar-cli config "MX Master 3S" smart-shift 18` call is unaffected. |

Polybar scripts (`polybar/*.sh`):

| Script         | Status                                            |
| -------------- | ------------------------------------------------- |
| `calnotify.sh` | Unchanged (notify-send + `cal`).                  |
| `bataverage.sh`| Unchanged (acpi).                                 |
| `adb-device.sh`| Unchanged (adb shell + notify-send).              |
| `screenthing.sh` | Unchanged (`screen -ls`).                       |

These all reappear as noctalia custom script-backed widgets. Per the
noctalia docs, custom widgets take an `exec` command and an interval
(same model as polybar's `custom/script` and waybar's `custom`),
plus optional click handlers — so the existing scripts' shapes
translate directly. Watch out for `tail = true` (polybar long-running
script mode): noctalia's equivalent for streaming output may be
named differently, check its widget docs.

### Things you can delete entirely

- `home-modules/graphical/sessions/i3/picom.nix`
- `xresources.path` setting + everything that writes to `~/.local/share/X11/`
- `xsession.{profilePath,scriptPath}` settings
- The `remove-xsession-errors` script in `i3/config/default.nix:52-59`
- The `xrandr --output ... --mode 1920x1080 --rate 144` triple in
  `home-configurations/reed@nixos-desktop/xsession.nix:14-16` (replaced
  by sway `output DP-X { mode 1920x1080@144Hz }` block)
- `XCOMPOSECACHE` env var is harmless to keep, but the X11 path becomes meaningless
- `MOZ_USE_XINPUT2 = "1"` in `home-modules/graphical/firefox.nix:11` → replace with `MOZ_ENABLE_WAYLAND = "1"` (or skip; modern Firefox auto-detects)
- `workspace-{1,2}.json` saved layouts under `i3/config/` — see
  "Saved workspace layouts" in pain points; sway has no compatible
  consumer, and the i3 `i3-save-tree` JSON format isn't reusable as-is.
  `workspace-4.json` is dropped — noctalia covers audio/bluetooth natively.

## NixOS-side changes

`nixos-modules/graphical/xserver.nix` is the single touchpoint:

```nix
# enable swayfx system-side (the commented block at lines 5-10 is the seed)
programs.sway = {
  enable = true;
  package = pkgs.swayfx.overrideAttrs (old: {
    passthru.providedSessions = [ "sway" ];
  });
};

services.displayManager.defaultSession = "sway";
# keep gdm.enable = true; (GDM happily hosts a sway session)
```

`swayfx` is in nixpkgs at 0.5.3.

Side effects to update at the same time:

- `security.pam.services.i3lock.enable = true;` in `nixos-modules/
  core/gnupg.nix:16` becomes whatever PAM service noctalia's lock
  binary expects (likely `noctalia-shell`, `quickshell`, or `swaylock`
  depending on what it links against — check `pam_unix.so` consumers
  in noctalia's source). PAM `gnome-keyring` integration on
  `gdm`/`login` stays. If noctalia's lock turns out to be too tightly
  scoped, falling back to `swaylock-effects` + `security.pam.services.swaylock.enable = true` is a clean exit.
- `systemd.services."lock-before-suspend"` in `xserver.nix:29-42`
  currently hard-codes `DISPLAY=:0` + `XAUTHORITY=.../gdm/Xauthority`.
  Under sway+noctalia, the cleanest replacement is to drop this
  systemd unit entirely and use noctalia's own idle/lock-on-suspend
  binding (it manages idle natively, which is the whole point of
  including it). If noctalia doesn't expose a "lock before
  suspend" hook, the fallback is a user-mode systemd unit that calls
  whatever noctalia's "lock now" IPC command is, with `WAYLAND_DISPLAY`
  and `XDG_RUNTIME_DIR` set from `%t` / `%u` template vars.
- `xdg.portal.extraPortals` currently has only `xdg-desktop-portal-gtk`.
  For sway you generally want `xdg-desktop-portal-wlr` *and* the gtk
  one (the wlr portal handles screencast/screenshot, gtk handles file
  pickers). Adding it is one line and has no cost on the GNOME session.
- `services.flameshot.enable` — leave on if you want it as a fallback,
  but plan to bind `Print` to `grim`/`grimblast`/`satty` in sway instead.

The desktop's `home-configurations/reed@nixos-desktop/xsession.nix`
(which also sets `xrandr` refresh rates and the easyeffects `pw-link`
calls) becomes a sway-equivalent file under the same directory; the
pipewire `pw-link` block is X11-independent and migrates verbatim.

## Application-by-application Wayland status

Compiled from the live package lists (`nix eval ...config.home.packages` /
`.config.environment.systemPackages`) on the desktop and t480:

### Native Wayland (no concern)

`kitty` (already), `firefox` (after dropping `MOZ_USE_XINPUT2`),
`mpv` (already), `zathura`, `dunst`, `signal-desktop`,
`telegram-desktop`, `obs-studio` (works with pipewire screencast portal),
`bitwarden-desktop` (Electron — needs `--ozone-platform-hint=auto`),
`vesktop`/`discord` via `nixcord` (Electron — same flag),
`easyeffects`, `pwvucontrol`, `qpwgraph` (Qt — Wayland-aware),
`adwsteamgtk`, `ludusavi`, `dconf-editor`, all GNOME stack.

### XWayland (works fine, slightly suboptimal)

`steam` (Valve has experimental native Wayland but XWayland is the
default), `bottles` (Wine), `prismlauncher` (Qt6 — actually native
Wayland in newer builds; check `QT_QPA_PLATFORM=wayland`),
`balatro-mod-manager`, all the emulators (`dolphin-emu`, `pcsx2`,
`eden`, `azahar`), `wheel-wizard`, `jdownloader` (Java/Swing — Java
on Wayland has known input/scaling issues; XWayland is safer),
`flameshot`, `filezilla`.

### X11-only / requires replacement

| Removed                                  | Replacement                                                                                                                |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `i3`                                     | `swayfx`                                                                                                                   |
| `picom`                                  | swayfx built-in                                                                                                            |
| `polybar`, `polybarFull`                 | `noctalia-shell` (bar component)                                                                                            |
| `dunst`                                  | `noctalia-shell` (notifications component)                                                                                  |
| `rofi` (for general launching)           | `noctalia-shell` (launcher component); **keep `rofi-wayland`** only for the `rofi-comma.sh` script                          |
| `i3lock-fancy` (via `lockProgram` alias) | `noctalia-shell` lock (with `swaylock-effects` as the documented fallback)                                                  |
| `xclip`, `xsel`                          | `wl-clipboard` (gives `wl-copy`, `wl-paste`)                                                                                |
| `clipnotify`                             | `wl-paste --watch`                                                                                                          |
| `maim` (used by `i3lock-fancy` override) | `grim`                                                                                                                     |
| `slop`                                   | `slurp`                                                                                                                    |
| `feh` (wallpaper)                        | noctalia wallpaper widget                                                                                                   |
| `xdotool`, `xwininfo`, `xprop`           | `swaymsg -t get_tree` + jq (only where the operation makes sense — see `killwrapper.sh` and `mpv-dnd.sh` discussion above) |
| `xinput`, `xset`, `xmodmap`              | sway `input`/`xkb_options` config, plus `keyd`/`kanata` for chord remaps                                                    |
| `xrandr`                                 | sway `output` config block, or `wlr-randr` for ad-hoc changes                                                               |
| (would-have-been: `swayidle`)            | `noctalia-shell` (idle component) — never added                                                                              |
| (would-have-been: `cliphist`)            | `noctalia-shell` (clipboard component) — never added                                                                         |

### Quirks worth a verification pass

- **Firefox** on Wayland uses different font rendering paths; the
  `gfx.webrender.all = true` setting in
  `home-modules/graphical/firefox.nix:47` already aligns with the
  Wayland renderer. Sanity-check `general.autoScroll` and the userChrome
  font sizing.
- **Telegram** has a hack in `home-modules/social/telegram.nix:8-19`:
  `wrapEnv telegram-desktop { XDG_CURRENT_DESKTOP = "gnome"; ... }`
  + a dconf `wm-preferences.button-layout = ":minimize,maximize,close"`
  rule. Comment in source says this exists to make Telegram close
  rather than minimize-to-tray. Re-test on swayfx — the workaround
  may become unnecessary (sway doesn't render system-side title bars
  the same way) or may need to be adjusted (`XDG_CURRENT_DESKTOP=sway`).
- **Discord / Vesktop** needs `--ozone-platform-hint=auto` for native
  Wayland; otherwise it runs under XWayland. The `nixcord` HM module
  exposes `commandLineArgs` — add the flag there.
- **OBS screen capture** uses xdg-desktop-portal screencast under
  Wayland; works with `xdg-desktop-portal-wlr`. PipeWire is already
  enabled, so this should "just work."
- **Logitech ratbagd / piper / solaar** are display-server-agnostic.
- **Droidcam** is a v4l2 device; XWayland-only consumers might need
  `droidcam-fix.sh` unchanged.
- **Adw-Steam-Gtk + custom CSS** in `home-modules/core/styling/extra/
  steam.nix` is unchanged.
- **Specialisation theme toggle** (`nixos-modules/core/styling/default.nix`)
  works without changes; you'll just want to also `swaymsg reload`
  and `systemctl --user restart waybar` after switching so the new
  base16 colors take effect.

## Pain points, ranked

1. **`killwrapper.sh` and `mpv-dnd.sh`.** These are the only scripts
   that rely on *global X11 window enumeration*. Wayland doesn't grant
   that. The pragmatic fix is:
   - For `killwrapper.sh`: stop fighting the "minimize to tray"
     behavior in Steam/Vesktop by configuring those apps to close
     instead, and delete the script.
   - For `mpv-dnd.sh`: rewrite around `swaymsg -t subscribe '["window"]'`,
     which fires events on focus changes; the rest of the script
     (SIGSTOP/SIGCONT of chat-app PIDs) is unchanged.

2. **Saved workspace layouts (`workspace-{1,2,4}.json`) — the
   biggest behavioral break in this migration.** This is
   [swaywm/sway#1005](https://github.com/swaywm/sway/issues/1005),
   closed as wontfix: the maintainer has explicitly decided not to
   support i3's `i3-save-tree` + `append_layout` workflow. Sway has
   a stub `append_layout` IPC command — the JSON is parsed and
   placeholder containers are created — but the swallow/match
   mechanism that's supposed to let a real window slot into a
   placeholder is brittle and has documented timing and orphan-
   container failure modes that aren't going to be fixed.

   **Scope is narrower than it looks.** Only workspaces 1 (Firefox)
   and 2 (chat apps) need layout restoration. Workspace 4
   (audio/bluetooth) goes away entirely: noctalia-shell's built-in
   audio controls and Bluetooth widget replace the need for a
   dedicated workspace, so `workspace-4.json` is simply dropped.

   The two scripts that use this — `load-layouts.sh` (which fires
   on `Mod+ctrl+N` to load a saved per-workspace layout *and* launch
   the matching apps) and `select-term.sh` (which uses `slop` +
   append_layout to place a one-off floating kitty in a user-selected
   region) — both have to be reworked rather than ported. The
   `load-layouts.sh` redesign only needs to cover workspaces 1 and 2.

   Three viable alternatives, listed in increasing fidelity to the
   original UX:

   - **Plain `swaymsg exec` + `sleep`.** Launch the apps in order and
     trust autotiling-rs / for_window rules to lay them out. This is
     what the comments on issue #1005 recommend. Loses the exact
     pixel-level placement but is the lowest-maintenance.
   - **`swayrst`** ([Nama/swayrst](https://github.com/Nama/swayrst))
     — a Python tool that reads a saved `get_tree` snapshot and
     reconstructs layouts by launching apps and using `swaymsg move`
     to slot them into position. Closest equivalent to your current
     workflow, but it does *launch then move* rather than *place
     then swallow*, so timing-sensitive cases (apps that take a while
     to start) need tuning.
   - **Custom GET_TREE → app_id mapping script** (à la
     [mishurov/srws.py](https://github.com/mishurov/applets/blob/master/sway_restore_workspace/srws.py))
     — same model as swayrst but hand-rolled. Worth it only if you
     want the script in this repo's vocabulary.

   For `select-term.sh` specifically, the cleanest sway-native
   equivalent is to skip placeholders entirely:
   `slurp` to get a region, then launch `kitty -T float`, then
   `for_window [app_id="kitty" title="float"] { floating enable;
   move position <x> <y>; resize set <w> <h> }`. No save/restore
   round-trip needed.

3. **`keybinds.sh` chord remaps.** Shift+Esc → tilde and PgUp/PgDown
   → Forward/Back keys can't be done in sway's xkb config. You'll
   want `keyd` (systemd-level, very clean Nix module) or
   `interception-tools`. Plan for an extra module here.

4. **Screen recording flow.** `record.sh` runs `ffmpeg -f x11grab`
   today. `wf-recorder -g "$(slurp)"` is the swap. The script's
   "if pgrep x11grab then SIGINT, else start" pattern translates
   cleanly to `pgrep wf-recorder`.

5. **`lockProgram` swap to noctalia's lock.** The `i3lock-fancy`
   override at `pkgs/alias.nix:30` is a single point of change. If
   noctalia exposes a "lock now" IPC/CLI command, the alias becomes
   a one-liner that invokes it. If noctalia's lock turns out to be
   non-scriptable from outside its own session (some Quickshell
   shells require IPC over a socket the shell creates at runtime),
   the fallback is `swaylock-effects` — in which case `grim` +
   `convert -blur 0x6` + `swaylock -i <out>.png` reproduces the
   i3lock-fancy screenshot-with-blur effect in about 10 lines.

6. **`lock-before-suspend` system service.** As written it assumes
   X11. Under noctalia, this should disappear entirely — noctalia
   handles idle and on-suspend lock natively. If it can't, the
   fallback is a user-scope service driven by `swayidle` with
   `before-sleep '${noctalia-lock-cmd}'` or `before-sleep '${swaylock} -f'`.

7. **GDM under GNOME 50.** The `services.displayManager.gdm.wayland`
   option was removed (you'll have seen this if you tried to set it —
   I hit the error in `nix eval`). GDM still works fine, but the
   session is selected at login. You can also consider `greetd +
   tuigreet` if you want a leaner stack since you don't need GUI
   account switching.

8. **Stylix targets for noctalia-shell + rofi.** Both present in
   stylix (verified). One configuration line each. The custom
   `telegram-desktop` and `steam` stylix targets stay where they are.
   The `dunst`, `polybar`, and `swaylock` targets that *would* have
   been needed under a waybar+dunst+swaylock layout are skipped —
   noctalia owns all of those surfaces.

9. **Noctalia config language (Quickshell/QML).** Polybar's config
   was an INI file produced by a Nix attribute set. Noctalia's
   configuration model is QML on top of Quickshell — a different
   beast. Quickshell itself is at v0.2.1 (early; API in flux) while
   noctalia is at v4.7.5 (more established but riding on that
   churning foundation). Expect a learning curve and a longer tail
   of "this worked yesterday, broke after an update" issues than
   you'd see with waybar+dunst+rofi+swaylock — that mature stack
   has years of inertia. Worth pinning the noctalia + quickshell
   packages until the dust settles.

## What you sacrifice (vs. what you keep)

### Sacrifices

- **i3-style "save a layout, swallow apps into it" workflow.** This
  is the most fundamental behavior change: sway's maintainers have
  closed the request and won't implement it. The replacement model
  (launch apps first, then move them into position) gives you the
  same end state but the round-trip and timing characteristics are
  different. See pain point #2 below for the full picture.
- The exact picom look. swayfx gives shadows, blur, corners, and
  per-window opacity, but its blur is single-pass and its shadow
  rules don't match picom's CSS-like exclusion language. You'll
  probably end up with a *similar* look but not pixel-identical.
- Sticky-window opacity dimming (`opacity-rule = "10:... STICKY ..."`).
  swayfx does support per-window opacity via `for_window`, but the
  "sticky" property is i3-specific. You'll need to express it
  differently — e.g. tag windows you want dimmed.
- Per-app keyboard chord remaps (Shift+Esc tilde, etc.) unless you
  add `keyd`/`kanata`. xmodmap-style ad-hoc rebinds vanish.
- The specific `flameshot` editing UX. The grim+slurp+swappy/satty
  trio is more powerful in some ways (no daemon) but the muscle
  memory differs.
- xeyes/xwininfo-style "look what window the cursor is on" tools.
  Wayland doesn't expose this globally. Mostly irrelevant unless you
  use them in scripts.

### What you keep

- All of stylix's color flow + the custom telegram/steam theme
  overrides.
- Mullvad VPN, autossh, Tailscale, NetworkManager, pipewire — all
  display-server-agnostic.
- Specialisation-based light/dark toggle (with a `swaymsg reload` +
  waybar restart added).
- The host-specific module split (impermanence, snapper, jellyfin,
  thelounge, btrfs, libvirt).
- All emulators / Steam library / Bottles / Wine games (via XWayland).
- The whole non-graphical surface: neovim, zsh, tmux, ranger, mpd,
  ncmpcpp, claude-code, persist-path-manager, ldp, gc, pin, all the
  custom packages under `pkgs/`.
- autotiling-rs (works on sway; in fact that's its primary target).

## Suggested migration sequence

1. **Add `home-modules/graphical/sessions/sway/` as a sibling of
   `i3/`.** Mirror the directory structure (`config/`, `polybar/` →
   `waybar/`, `rofi/`). Don't touch the `i3/` tree.
2. **Wire it behind a switch.** In `sessions/default.nix`, import
   `./sway` only when a custom option (e.g. `custom.session = "sway"`)
   selects it; default to `"i3"` for now. Same idea on the NixOS side
   in `xserver.nix` for `programs.sway.enable` and `defaultSession`.
3. **Port the trivially-translatable surface first**:
   - `wayland.windowManager.sway.config` from `i3.config`
   - keybindings (s/i3-msg/swaymsg/)
   - kitty, mpv, zathura (unchanged)
   - stylix targets: enable `sway`, `noctalia-shell`; keep `rofi`
     enabled (still used by rofi-comma); leave the i3/polybar/dunst
     targets on the i3 path.
   - `lockProgram` swap (point at noctalia's lock command; keep
     `swaylock-effects` available as the documented fallback)
4. **Bring up noctalia-shell.** Replace four things at once: polybar,
   dunst, rofi-for-launching, and swaybg. The four polybar custom
   scripts (`screenthing`, `bataverage`, `adb-device`, `calnotify`)
   become noctalia custom widgets with the same `exec`/`interval`
   shape. Map polybar's `internal/i3` workspace module to noctalia's
   workspaces widget. Map polybar's `internal/date` to noctalia's
   clock widget. Verify the notification path end-to-end
   (`brightness.sh` → `dunstify` → noctalia toast) — your scripts
   pass `-h string:x-dunst-stack-tag:brightness` which is
   dunst-specific; if noctalia ignores the tag you'll get notification
   pile-up on rapid brightness presses. Worth re-reading those scripts.
5. **Port scripts** in dependency order:
   - `volume.sh`, `brightness.sh`, `dwebp-serv.sh`, `droidcam-fix.sh`
     (no changes)
   - `clipboard-clean.sh`, `record.sh`, `toggle-touchpad.sh`,
     `select-term.sh`, `load-layouts.sh` (mechanical X11→Wayland)
   - `keybinds.sh` (split between sway input config + new `keyd` module)
   - `mpv-dnd.sh` (rewrite around `swaymsg -t subscribe`)
   - `killwrapper.sh` (likely delete + disable tray-minimize in apps)
6. **Switch one host (the VM is the safest test bed; the t480 is the
   most forgiving for graphics drivers).** Verify portals, screen
   recording, screen sharing, lockscreen-on-suspend, theme toggle.
7. **Move the desktop last** — it has the multi-display refresh-rate
   override and the line-in-to-easyeffects autorun that you don't
   want to debug under a partial port.

## Effort estimate

Assuming you're comfortable in both i3 and sway and don't need to
research from scratch:

- Skeleton (sway module + stylix wiring + lockProgram alias swap):
  ~0.5 day.
- Noctalia bring-up: bar layout, four custom widgets, notifications
  smoke-test, launcher key-binding, wallpaper hookup, lock/idle config:
  ~1 day. (More than a waybar-only port because noctalia owns more
  surfaces, less than waybar + dunst + rofi-launcher + swaylock +
  swayidle + swaybg done separately. And the Quickshell/QML learning
  curve is the unknown — could be 0.5d or 1.5d depending on familiarity.)
- Mechanical script ports (volume/brightness untouched, clipboard,
  record, toggle-touchpad): ~0.5 day.
- Harder script work (keybinds split with keyd, mpv-dnd subscribe-based
  rewrite, killwrapper deletion/alternative): ~1 day.
- `load-layouts.sh` + `select-term.sh` redesign (workspaces 1+2
  only; workspace 4 dropped — noctalia covers audio/bluetooth natively;
  pick between swaymsg-exec scripts, swayrst, or custom GET_TREE
  walker; rebuild the two-workspace launch flow; tune sleeps): ~0.5
  day. Lower-risk than it looks given the reduced scope.
- First-host bring-up + xdg-portal/screencast reshuffle + ironing
  out app-launch flags (Discord ozone, Firefox MOZ_ENABLE_WAYLAND,
  Telegram XDG_CURRENT_DESKTOP recheck): ~0.5–1 day.
- Tail of "this one specific app misbehaves" issues: variable; budget
  ~0.5 day across the first week of daily use. Add a bit of buffer
  for noctalia/quickshell upstream churn.

**Total: 4–5.5 working days** to a confident daily-drive state, with
a soft tail afterwards. The fact that the i3 session can stay enabled
the whole time (you literally just select a different session at
login) is the single biggest risk reducer here. Noctalia consolidates
several pieces of the migration into one component, but introduces a
new config language (QML on Quickshell) to learn, so the total is
roughly a wash relative to a waybar-stack migration.
