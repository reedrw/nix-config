#! /usr/bin/env nix-shell
#! nix-shell -i bash

export NIXPKGS_ALLOW_UNFREE=1
systemProfile="/nix/var/nix/profiles/system"

getChannelURL(){
  nix-channel --list | grep "$1 " | cut -d' ' -f2
}

getPinnedURL(){
  jq -r ".[\"$1\"].url" ./nix/sources.json
}

system(){
  local host
  local currentSystemDrv
  local newSystemDrv

  host="$(hostname)"
  # if the hostname matches a saved configuration.nix
  if [[ -f "./system/$host.nix" ]]; then
    currentSystemDrv="$(nix-store --query --deriver "$systemProfile")"
    newSystemDrv="$(nix-instantiate ci.nix -A "$host" 2> /dev/null)"
    # compare deriver of current and new system builds, if different, rebuild
    if [[ "$currentSystemDrv" != "$newSystemDrv" ]]; then
      echo "Rebuilding NixOS..."
      sudo nixos-rebuild switch -I nixos-config="$dir"/system/"$host".nix |& nom
    else
      echo "No changes to system. Not rebuilding."
    fi
  else
    echo "Rebuilding NixOS..."
    ( sudo nixos-rebuild switch |& nom ) || exit 1
  fi
}

hm(){
  local HomeManagerProfile
  local currentHomeManagerDrv
  local newHomeManagerDrv

  HomeManagerProfile="/nix/var/nix/profiles/per-user/$USER/home-manager"
  currentHomeManagerDrv="$(nix-store --query --deriver "$HomeManagerProfile")"
  newHomeManagerDrv="$(nix-instantiate ci.nix -A home-manager 2> /dev/null)"
  if [[ "$currentHomeManagerDrv" != "$newHomeManagerDrv" ]]; then
    echo "Rebuilding home-manager..."
    ( unbuffer home-manager switch |& nom )|| exit 1
  else
    echo "No changes to home-manager. Not rebuilding."
  fi
}

updateNixpkgs(){
  local channelName
  local nixChannel
  local user

  user="${1:-$USER}"
  channelName="${2:-nixpkgs}"
  nixChannel="nix-channel"
  if [[ "$user" == "root" ]]; then
    nixChannel="sudo -i $nixChannel"
  fi
  echo "Installing pinned nixpkgs as $user..."
  $nixChannel --add "$nixpkgsURL" "$channelName"
  $nixChannel --update
}

updateHomeManager(){
  echo "Installing pinned home-manager..."
  nix-channel --add "$HomeManagerURL" home-manager
  nix-channel --update
}

checkForUpdates(){
  local currentHomeManagerURL
  local currentNixpkgsURL

  currentHomeManagerURL="$(getChannelURL home-manager)"
  currentNixpkgsURL="$(getChannelURL nixpkgs)"

  [[ "$currentHomeManagerURL" != "$HomeManagerURL" ]] \
    && hmUpdateNeeded="true"

  [[ "$currentNixpkgsURL" != "$nixpkgsURL" ]] \
    && nixpkgsUpdateNeeded="true"
}

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit
  HomeManagerURL="$(getPinnedURL home-manager)"
  nixpkgsURL="$(getPinnedURL nixpkgs)"

  # if a system profile exists (NixOS check)
  if [[ -d "$systemProfile" ]]; then
    onNixOS="true"
  elif [[ -d "/nix/var/nix/profiles/per-user/root/channels/nixpkgs" ]]; then
    multiUser="true"
  fi

  checkForUpdates

  [[ -n "$hmUpdateNeeded" ]] && updateHomeManager

  if [[ -n "$nixpkgsUpdateNeeded" ]]; then
    updateNixpkgs
    # TODO: add check for non-NixOS multi-user install
    [[ -n "$onNixOS" ]] && updateNixpkgs root nixos
    [[ -n "$multiUser" ]] && updateNixpkgs root
  fi

  # Update NIX_PATH here or else you'd need to log out
  export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}

  [[ -n "$onNixOS" ]] && (system || exit 1)
  hm || exit 1
popd > /dev/null || exit
