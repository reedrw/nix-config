#!/usr/bin/env nix-shell
#! nix-shell -i bash -p sway jq procps

# Suspends chat-app processes while mpv/Zathura is focused.
# Runs as a systemd user service; called with process names to manage.
#
# Usage: mpv-dnd [--resume] <proc-name>...
#   --resume   SIGCONT all managed processes and exit (for workspace-switch keybind)

set -euo pipefail

programs=()
for arg in "$@"; do
  [[ "$arg" != "--resume" ]] && programs+=("$arg")
done

highPrio=("mpv" "Zathura" "org.pwmt.zathura")

isHighPrio(){
  local appId="$1"
  for hp in "${highPrio[@]}"; do
    [[ "$appId" == "$hp" ]] && return 0
  done
  return 1
}

stopPrograms(){
  for prog in "${programs[@]}"; do
    while IFS= read -r pid; do
      kill -STOP "$pid" 2>/dev/null || true
    done < <(pgrep -f "$prog" 2>/dev/null || true)
  done
}

contPrograms(){
  for prog in "${programs[@]}"; do
    while IFS= read -r pid; do
      kill -CONT "$pid" 2>/dev/null || true
    done < <(pgrep -f "$prog" 2>/dev/null || true)
  done
}

# --resume mode: one-shot SIGCONT from workspace-switch keybind
for arg in "$@"; do
  if [[ "$arg" == "--resume" ]]; then
    contPrograms
    exit 0
  fi
done

# Wait for sway socket to become available (service may start before sway)
until [ -S "${SWAYSOCK:-}" ] || SWAYSOCK="$(find /run/user/"$(id -u)"/ -maxdepth 1 -name 'sway*.sock' 2>/dev/null | head -1)" && [ -S "$SWAYSOCK" ]; do
  sleep 1
done
export SWAYSOCK

# Subscribe to sway window focus events and react
while IFS= read -r event; do
  change="$(printf '%s' "$event" | jq -r '.change // empty' 2>/dev/null)"
  [[ "$change" != "focus" ]] && continue

  appId="$(printf '%s' "$event" | jq -r '.container.app_id // .container.window_properties.class // empty' 2>/dev/null)"
  [[ -z "$appId" ]] && continue

  if isHighPrio "$appId"; then
    stopPrograms
  else
    contPrograms
  fi
done < <(swaymsg -t subscribe '["window"]')
