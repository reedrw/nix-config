#!/usr/bin/env bash

set -x
set -e

cmd="$(rofi -show run -run-command 'echo {cmd}' "${@}" )"

# Count the number of words in input,
# if number of word > 1, get arguments
# shellcheck disable=2086
set -- $cmd
[ $# -gt 1 ] \
  && args="${cmd#* }" \
  && read -ra args <<< "${args}"

# Set input to array and get first item,
# which is the command
read -ra cmda <<< "${cmd}"
cmd="${cmda[*]:0:1}"

if [ -x "$(command -v "$cmd")" ]; then
  ("$cmd" "${args[@]}" &)
else

  if [ -f "$HOME/.cache/nix-index/files" ]; then
    database="$HOME/.cache/nix-index"
  else
    rofi -e 'No database.'
    return 1
  fi

  attr="$(nix-locate --db "$database" --top-level --minimal --at-root --whole-name "/bin/$cmd")"

  if [ -z "$attr" ]; then
    rofi -e "$cmd: command not found"
    return 127
  fi

  attr="$(echo "$attr" | rofi "${@}" -dmenu -p "Run from nix package?")" || return 130

  nix shell "nixpkgs#$attr" -c "$cmd" "${args[@]}"
fi

