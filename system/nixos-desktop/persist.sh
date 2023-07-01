#!/usr/bin/env bash

set -e
# trap 'handleErrors "$?"' ERR

configJson="$HOME/.config/persist-path-manager/config.json"

main(){
  parseConfig
  # If there are no args, show help and exit
  if [[ "$#" == '0' ]]; then
    show_help
  fi

  case $1 in
    -h|--help)
      show_help
      ;;
    -l|--list)
      list
      ;;
    -v|--verbose)
      set -x
      export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
      shift
      main "$@"
      ;;
    -r|--remove)
      shift;
      remove "$@"
      ;;
    *)
      add "$@"
      ;;
  esac
}

show_help() {
  fileName="$(basename "$0")"
  underline=$(tput smul)
  yellow=$(tput setaf 3)
  green=$(tput setaf 2)
  blue=$(tput setaf 4)
  reset=$(tput sgr0)
  bold=$(tput bold)

  echo "Usage: ${bold}$fileName${reset} [${yellow}OPTIONS${reset}] [${underline}PATH${reset}]

${green}${bold}Options:${reset}
  ${yellow}-r, --remove${reset}     Remove the specified path from persistence.
  ${yellow}-l, --list${reset}       List all persistent files and directories.
  ${yellow}-v, --verbose${reset}    Show verbose output for debugging purposes.
  ${yellow}-h, --help${reset}       Show this help message and exit.

${green}${bold}Examples:${reset}
  ${bold}$fileName /path/to/directory${reset}       Add a directory to persistence
  ${bold}$fileName -r /path/to/file.txt${reset}     Remove a file from persistence

${green}${bold}Description:${reset}
  This script for NixOS systems with ephemeral root allows you to manage
  persistent files and directories. When given a path as an argument, it
  will be copied to the '/persist' directory, and a snapshot will be
  created using the 'snapper' tool. The added items will be automatically
  restored on system activation.

  Nix can parse the 'persist.json' file using the 'builtins.fromJSON' function.
  For example:
    ${blue}${bold}json = (builtins.fromJSON (builtins.readFile ./persist.json));${reset}

If no options are provided, the specified path will be added to persistence.
"
  exit 0
}


parseConfig(){
  local tmpJson
  tmpJson="$(mktemp)"

  if ! [[ -f "$configJson" ]]; then
    mkdir -p "$(dirname "$configJson")"
    jq > "$tmpJson" << EOF
      {
        "activateCommand": "",
        "persistJson": "$(dirname "$configJson")/persist.json",
        "persistDir": "/var/persist",
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
  persistDir="$(jq -r '.persistDir' "$configJson")"
  useSnapper="$(jq -r '.snapper.enable' "$configJson")"
  snapperConfig="$(jq -r '.snapper.config' "$configJson")"

  # Create persist.json if it doesn't exist
  ! [[ -f "$persistJson" ]] &&
    echo '{ "files": [], "directories": [] }' | jq > "$persistJson"

  # Check if persistDir is a directory
  if ! [[ -d "$persistDir" ]]; then
    echo "The specified perist directory ($persistDir) is not a directory or does not exist."
    exit 204
  fi

  # Check if activateCommand is set
  if [[ -z "$activateCommand" ]]; then
    echo "Make sure you set activateCommand in $configJson"
    echo
    echo "Ex:"
    jq -r ".activateCommand |= \"sh -c 'sudo nixos-rebuild switch && home-manager switch'\"" "$configJson"
    exit 7
  fi
}

# handleErrors(){
#   # Clean tmp files in case of error
#   rm -f "$tmpJson"
#
#   # restore original perist.json if it was modified
# }

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

parseFileArgs(){
  local removalSubstring
  removalSubstring=""
  # Resolve the absolute path of the input argument
  fileArg="$(realpath "$1")"

  # Store the original path for later use
  fileArgOrigPath="$fileArg"

  # Determine the new location for the path within "/persist" if needed
  # This step allows the user to persist files directly from their file paths
  # within snapshots or previous boots, while still maintaining the correct
  # relative directory structure within "/persist".
  if [[ "$fileArg" == /prev/* ]]; then
    removalSubstring='s|/prev/[0-9]\+||g'
    fileArg="$(echo "$fileArg" | sed "$removalSubstring")"
    newLoc="$(dirname "$persistDir$fileArg")"
  elif [[ "$fileArg" == "$persistDir/.snapshots/"* ]]; then
    removalSubstring="s|$persistDir/.snapshots/.*/snapshot||g"
    fileArg="$(echo "$fileArg" | sed "$removalSubstring")"
    newLoc="$(dirname "$persistDir$fileArg")"
  elif [[ "$fileArg" == "$persistDir/"* ]]; then
    removalSubstring="s|$persistDir||g"
    # Paths already within "/persist" don't need newLoc handling
    fileArg="$(echo "$fileArg" | sed "$removalSubstring")"
  else
    # Handle other paths by copying to "/persist/<directory>"
    newLoc="$persistDir$(dirname "$fileArg")"
  fi

  # Check if the path exists
  if ! pathExists "$fileArgOrigPath"; then
    echo "Path $1 does not exist."
    return 53
  fi

  # Check if the path is a directory
  if [[ -d "$fileArgOrigPath" ]]; then
    isDir="yes"
  fi
}

pathExists(){
  if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
    return 0
  else
    return 1
  fi
}

add() {
  local tmpJson
  tmpJson="$(mktemp)"

  parseFileArgs "$@"

  echo "Adding path $(tput setaf 2)$fileArg$(tput sgr0) to persistence."

  # Update the JSON data based on the path type (file or directory)
  if [[ -n "$isDir" ]]; then
    # Add the directory path to the JSON data and ensure uniqueness
    jq -r ".directories[.directories | length] |= . + \"$fileArg\"" "$persistJson" |
      jq -r '.directories |= if . then sort else empty end' | jq '.directories |= unique' > "$tmpJson"
  else
    # Add the file path to the JSON data and ensure uniqueness
    jq -r ".files[.files | length] |= . + \"$fileArg\"" "$persistJson" |
      jq -r '.files |= if . then sort else empty end' | jq '.files |= unique' > "$tmpJson"
  fi

  # Update the main 'persist.json' file with the updated JSON data
  cat "$tmpJson" > "$persistJson"
  rm "$tmpJson"

  if [[ -n "$newLoc" ]]; then
    # Create the necessary directories in the new location
    mkdir -p "$newLoc"

    # Copy the path to the new location and create a snapshot if enabled
    if [[ "$useSnapper" == "true" ]]; then
      snapper -c "$snapperConfig" create --command "cp -rp --reflink $fileArgOrigPath $newLoc" -d "persist $fileArg"
    else
      cp -rp --reflink "$fileArgOrigPath" "$newLoc"
    fi

    if pathExists "$fileArg"; then
      # Rename the original path by appending ".bak" to avoid conflicts
      moveBack="yes"
      mv "$fileArg" "$fileArg.bak"
    fi
  fi

  # Activate the NixOS generations and handle activation failures
  if eval "$activateCommand" || (mountpoint "$fileArg" > /dev/null || pathExists "$fileArg"); then
    [[ -z "$moveBack" ]] || rm -r "$fileArg.bak"
  else
    [[ -z "$moveBack" ]] || mv "$fileArg.bak" "$fileArg"
  fi
}

remove(){
  local tmpJson
  tmpJson="$(mktemp)"

  # Parse the provided file arguments and determine if they are directories or files
  parseFileArgs "$@"

  # Check if the provided path exists in the persist.json file
  # by searching for it in the appropriate JSON array (directories or files).
  # If the path is not found, exit with an error code.
  if [[ -n "$isDir" ]]; then
    exists=$(jq -r ".directories[] | select(. == \"$fileArg\")" "$persistJson")
  else
    exists=$(jq -r ".files[] | select(. == \"$fileArg\")" "$persistJson")
  fi

  if [[ -z "$exists" ]]; then
    echo "Provided path is not present in persist.json."
    exit 52
  fi

  echo "Removing $(tput setaf 1)$fileArg$(tput sgr0) from persistence."

  # Remove the path from the appropriate JSON array (directories or files).
  # This is done by using the 'jq' command to delete the matching entry from the array.
  # The resulting JSON data is saved in a temporary file.
  if [[ -d "$fileArg" ]]; then
    jq -r ".directories |= del(.[index(\"$fileArg\")])" "$persistJson" > "$tmpJson"
  else
    jq -r ".files |= del(.[index(\"$fileArg\")])" "$persistJson" > "$tmpJson"
  fi
  cat "$tmpJson" > "$persistJson"
  rm "$tmpJson"

  # Determine the path within the persisted directory ("/persist") where the item was located.
  # This is used later to prompt the user to delete the corresponding directory or file.
  persistLoc="$persistDir$(dirname "$fileArg")"

  # If the NixOS generations activation command succeeds and the item is a directory,
  # remove the directory from the original location. As it was perviously a mountpoint,
  # and should now be empty. Make sure it's empty before removing it.
  if eval "$activateCommand" && [[ -d "$fileArg" ]] && [[ -z "$(ls -A "$fileArg")" ]]; then
    rm -rf "$fileArg"
  fi

  # Prompt the user to confirm the deletion of the item from the persisted directory ("/persist").
  # Depending on the user's choice, the item will be deleted from the persisted directory.
  read -rp "Delete $persistLoc/$(basename "$fileArg")? [y/N]: " yn
  case "$yn" in
    [Yy]*)
      # If the 'useSnapper' option is set to true, create a new snapshot and then delete the item.
      # Otherwise, directly delete the item from the persisted directory.
      if [[ "$useSnapper" == "true" ]]; then
        snapper -c persist create --command "rm -rf ${persistLoc:?}/$(basename "${fileArg:?}")" -d "remove $fileArg"
      else
        rm -rf "${persistLoc:?}/$(basename "${fileArg:?}")"
      fi
    ;;
    *) exit 0;; # If the user chooses not to delete, exit the function without performing any deletion.
  esac
}

main "$@"
