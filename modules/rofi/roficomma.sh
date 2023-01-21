#!/usr/bin/env bash

set -x
set -e

rofiArgs="${*}"
cmd="$(rofi "$rofiArgs" -show run -run-command 'echo {cmd}')"

# Count the number of words in input,
# if number of word > 1, get command and arguments
# shellcheck disable=2086
set -- $cmd
[ $# -gt 1 ] \
  && read -ra args <<< "${cmd}" \
  && cmd="${args[*]:0:1}" \
  && args=("${args[@]:1}")

[ -z "$cmd" ] && exit 1

if [ -x "$(command -v "$cmd")" ]; then
  ("$cmd" "${args[@]}" &)
else

  if [ -f "$HOME/.cache/nix-index/files" ]; then
    database="$HOME/.cache/nix-index"
  else
    rofi "$rofiArgs" -e 'No database.'
    exit 1
  fi

  attr="$(nix-locate -d "$database" --top-level --minimal --at-root -w "/bin/$cmd")"

  if [ -z "$attr" ]; then
    rofi "$rofiArgs" -e "$cmd: command not found"
    exit 127
  fi

  attr="$(rofi "$rofiArgs" -dmenu -p "Run from nix package?" <<< "$attr")" \
    && (nix shell "nixpkgs#$attr" -c "$cmd" "${args[@]}" &)
fi

