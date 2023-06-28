#!/usr/bin/env bash

set -e

runDir="$(dirname "$0")"
persistJson="$runDir/persist.json"
tmpJson="$(mktemp)"

! [[ -f "$persistJson" ]] &&
  echo '{ "files": [], "directories": [] }' | jq > "$persistJson"

show_help() {
  fileName="$(basename "$0")"
  bold=$(tput bold)
  reset=$(tput sgr0)
  underline=$(tput smul)
  yellow=$(tput setaf 3)
  green=$(tput setaf 2)
  blue=$(tput setaf 4)

  echo "Usage: ${bold}$fileName${reset} [${yellow}OPTIONS${reset}] [${underline}PATH${reset}]"
  echo
  echo "${green}${bold}Options:${reset}"
  echo "  ${yellow}-r, --remove${reset}     Remove the specified path from persistence."
  echo "  ${yellow}-l, --list${reset}       List all persistent files and directories."
  echo "  ${yellow}-h, --help${reset}       Show this help message and exit."
  echo
  echo "${green}${bold}Examples:${reset}"
  echo "  ${bold}$fileName /path/to/directory${reset}       Add a directory to persistence"
  echo "  ${bold}$fileName -r /path/to/file.txt${reset}     Remove a file from persistence"
  echo
  echo "${green}${bold}Description:${reset}"
  echo "  This script for NixOS systems with ephemeral root allows you to manage"
  echo "  persistent files and directories. When given a path as an argument, it"
  echo "  will be copied to the '/persist' directory, and a snapshot will be"
  echo "  created using the 'snapper' tool. The added items will be automatically"
  echo "  restored on system activation."
  echo
  echo "  Nix can parse the 'persist.json' file using the 'builtins.fromJSON' function."
  echo "  For example:"
  echo "    ${blue}${bold}json = (builtins.fromJSON (builtins.readFile ./persist.json));${reset}"
  echo
  echo "If no options are provided, the specified path will be added to persistence."
  echo
  exit 0
}

pathExists(){
  if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
    return 0
  else
    return 1
  fi
}

add(){
  fileArg="$(realpath "$1")"
  if ! pathExists "$fileArg"; then
    echo "Path $1 does not exist or cannot be persisted."
    exit 43
  fi

  fileArgOrigPath="$fileArg"

  if [[ -d "$fileArg" ]]; then
    isDir="yes"
  fi

  if [[ "$fileArg" == /prev/* ]]; then
    newLoc="$(dirname "/persist${fileArg#/prev}")"
    fileArg="${fileArg#/prev}"
  elif [[ "$fileArg" == /persist/.snapshots/* ]]; then
    newLoc="$(dirname "/persist${fileArg#/persist/.snapshots/*/snapshot}")"
    fileArg="${fileArg#/persist/.snapshots/*/snapshot}"
  else
    newLoc="/persist$(dirname "$fileArg")"
  fi

  echo "Adding path $fileArg to persistence."

  # Add to json
  if [[ -n "$isDir" ]]; then
    jq -r ".directories[.directories | length] |= . + \"$fileArg\"" "$persistJson" |
      jq -r '.directories |= if . then sort else empty end' | jq '.directories |= unique' > "$tmpJson"
  else
    jq -r ".files[.files | length] |= . + \"$fileArg\"" "$persistJson" |
      jq -r '.files |= if . then sort else empty end' | jq '.files |= unique' > "$tmpJson"
  fi
  cat "$tmpJson" > "$persistJson"

  mkdir -p "$newLoc"

  # Make new snapshot and copy to /persist
  snapper -c persist create --command "cp -rp --reflink $fileArgOrigPath $newLoc" -d "persist $fileArg"

  # Rename so file isn't in the way of NixOS generation activation.
  if pathExists "$fileArg"; then
    moveBack="yes"
    mv "$fileArg" "$fileArg.bak"
  fi

  # Activate. If activation fails, and the file location is
  # not a mount (for directories) or symlink (for files).
  # ldp is my alias for sh -c 'nixos-rebuild switch; home-manager switch'
  if ldp ||  ( mountpoint "$fileArg" || pathExists "$fileArg" ); then
    [[ -z "$moveBack" ]] || rm -r "$fileArg.bak"
  else
    [[ -z "$moveBack" ]] || mv "$fileArg.bak" "$fileArg"
  fi
}

remove(){
  fileArg="$(realpath "$1")"

  if [[ "$fileArg" == /persist/* ]]; then
    fileArg="${fileArg#/persist}"
  fi

  # Check if the value exists in persist.json
  if [[ -d "$fileArg" ]]; then
    exists=$(jq -r ".directories[] | select(. == \"$fileArg\")" "$persistJson")
  else
    exists=$(jq -r ".files[] | select(. == \"$fileArg\")" "$persistJson")
  fi

  if [[ -z "$exists" ]]; then
    echo "Provided path is not present in persist.json."
    exit 52
  fi

  echo "Removing $fileArg from persistence."

  # modify json
  if [[ -d "$fileArg" ]]; then
    jq -r ".directories |= del(.[index(\"$fileArg\")])" "$persistJson" > "$tmpJson"
  else
    jq -r ".files |= del(.[index(\"$fileArg\")])" "$persistJson" > "$tmpJson"
  fi
  cat "$tmpJson" > "$persistJson"

  # Find the corresponding directory in /persist
  persistDir="/persist$(dirname "$fileArg")"

  # Make a new snapshot and remove from /persist
  snapper -c persist create --command "rm -rf $persistDir/$(basename "$fileArg")" -d "remove $fileArg"

  # Activate the removal
  if ldp && [[ -d "$fileArg" ]]; then
    rm -rf "$fileArg"
  fi
}

list(){
  files=$(jq -r '.files[]' "$persistJson")
  directories=$(jq -r '.directories[]' "$persistJson")

  if [[ -n "$files" ]]; then
    echo "Persistent Files:"
    tput setaf 4
    echo "$files" | while read -r file; do
      echo "$file"
    done
    tput sgr0
    echo
  fi

  if [[ -n "$directories" ]]; then
    echo "Persistent Directories:"
    tput setaf 2
    echo "$directories" | while read -r directory; do
      echo "$directory"
    done
    tput sgr0
  fi
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
elif [[ "$1" == "-l" || "$1" == "--list" ]]; then
  list
elif [[ "$1" == "-r" || "$1" == "--remove" ]]; then
  shift;
  remove "$@"
else
  add "$@"
fi
