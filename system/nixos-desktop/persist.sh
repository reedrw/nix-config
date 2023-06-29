#!/usr/bin/env bash

# set -x
# export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -e

configJson="$HOME/.config/persist-path-manager/config.json"
tmpJson="$(mktemp)"

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

parseConfig(){
  if ! [[ -f "$configJson" ]]; then
    mkdir -p "$(dirname "$configJson")"
    jq > "$tmpJson" << EOF
      {
        "activateCommand": "",
        "persistJson": "$(dirname "$configJson")/persist.json",
        "snapper": {
          "enable": false,
          "config": "persist"
        }
      }
EOF
  cat "$tmpJson" > "$configJson"
  rm "$tmpJson"
  fi
  activateCommand="$(jq -r '.activateCommand' "$configJson")"
  persistJson="$(jq -r '.persistJson' "$configJson")"
  useSnapper="$(jq -r '.snapper.enable' "$configJson")"
  snapperConfig="$(jq -r '.snapper.config' "$configJson")"

  if [[ -z "$activateCommand" ]]; then
    echo "Make sure you set activateCommand in $configJson"
    echo
    echo "Ex:"
    jq -r ".activateCommand |= \"sh -c 'sudo nixos-rebuild switch && home-manager switch'\"" "$configJson"
    exit 7
  fi
}

parseConfig

! [[ -f "$persistJson" ]] &&
  echo '{ "files": [], "directories": [] }' | jq > "$persistJson"

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
  elif [[ "$fileArg" == /persist/* ]]; then
    fileArg="${fileArg#/persist}"
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
  rm "$tmpJson"

  if [[ -n "$newLoc" ]]; then
    mkdir -p "$newLoc"

    # Make new snapshot and copy to /persist
    if [[ "$useSnapper" == "true" ]]; then
      snapper -c "$snapperConfig" create --command "cp -rp --reflink $fileArgOrigPath $newLoc" -d "persist $fileArg"
    else
      cp -rp --reflink "$fileArgOrigPath" "$newLoc"
    fi

    # Rename so file isn't in the way of NixOS generation activation.
    if pathExists "$fileArg"; then
      moveBack="yes"
      mv "$fileArg" "$fileArg.bak"
    fi
  fi

  # Activate. If activation fails, and the file location is
  # not a mount (for directories) or symlink (for files).
  # activateCommand is the command run to activate the NixOS generations.
  # Eg. sh -c 'nixos-rebuild switch; home-manager switch'
  if eval "$activateCommand" ||  ( mountpoint "$fileArg" > /dev/null || pathExists "$fileArg" ); then
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
  rm "$tmpJson"

  # Find the corresponding directory in /persist
  persistDir="/persist$(dirname "$fileArg")"

  # Activate the removal
  if eval "$activateCommand" && [[ -d "$fileArg" ]]; then
    rm -rf "$fileArg"
  fi

  # Make a new snapshot and remove from /persist
  read -rp "Delete $persistDir/$(basename "$fileArg")? [y/N]: " yn
  case "$yn" in
    [Yy]*)
      if [[ "$useSnapper" == "true" ]]; then
        snapper -c persist create --command "rm -rf ${persistDir:?}/$(basename "${fileArg:?}")" -d "remove $fileArg"
      else
        rm -rf "${persistDir:?}/$(basename "${fileArg:?}")"
      fi
    ;;
    *) exit 0;;
  esac
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
