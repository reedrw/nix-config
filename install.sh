#! /usr/bin/env nix-shell
#! nix-shell -i bash

export NIXPKGS_ALLOW_UNFREE=1

if [[ -n "$SUDO_ASKPASS" ]]; then
  sudo="sudo -A"
else
  sudo="sudo"
fi

host="$(hostname)"
dir="$(dirname "$0")"

pushd "$dir" > /dev/null || exit

HomeManagerURL="$(jq -r '.["home-manager"].url' ./sources.json)"
nixpkgsURL="$(jq -r '.["nixpkgs"].url' ./sources.json)"

getTarballHash(){
  tmpDir="$(mktemp -d)/"
  wget -nv --show-progress -c "$1" -O - | tar xz -C "$tmpDir" --strip-components=1
  nix-hash --type sha256 "$tmpDir"
  rm -r "$tmpDir"
}

currentHomeManager="/nix/var/nix/profiles/per-user/$USER/channels/home-manager/"
currentHomeManagerSha="$(nix-hash --type sha256 "$currentHomeManager")"
newHomeManagerSha="$(getTarballHash "$HomeManagerURL")"
if [[ "$currentHomeManagerSha" != "$newHomeManagerSha" ]]; then
  echo "Installing pinned home-manager..."
  nix-channel --add "$HomeManagerURL" home-manager
  nix-channel --update

  # Update NIX_PATH here or else you'd need to log out
  export NIX_PATH=$NIX_PATH:$HOME/.nix-defexpr/channels
fi

currentNixpkgs="/nix/var/nix/profiles/per-user/root/channels/nixos/"
currentNixpkgsSha="$(nix-hash --type sha256 "$currentNixpkgs")"
newNixpkgsSha="$(getTarballHash "$nixpkgsURL")"
if [[ "$currentNixpkgsSha" != "$newNixpkgsSha" ]]; then
  echo "Installing pinned nixpkgs..."
  $sudo nix-channel --add "$nixpkgsURL" nixos
  $sudo nix-channel --update
  echo "Updating search cache..."
  nix search -u > /dev/null
fi

system(){
  # if the hostname matches a saved configuration.nix
  if [[ -d "./system/$host" ]]; then
    currentSystemDrv="$(nix-store --query --deriver "$systemProfile")"
    newSystemDrv="$(nix-instantiate ci.nix -A "$host" 2> /dev/null)"
    # compare deriver of current and new system builds, if different, rebuild
    if ! [[ "$currentSystemDrv" == "$newSystemDrv" ]]; then
      echo "Rebuilding NixOS..."
      $sudo nixos-rebuild switch -I nixos-config="$dir"/system/"$host".nix
    else
      echo "No changes to system. Not rebuilding."
    fi
  else
    echo "Rebuilding NixOS..."
    $sudo nixos-rebuild switch
  fi
}

systemProfile="/nix/var/nix/profiles/system"
# if a system profile exists (NixOS check)
if [[ -d "$systemProfile" ]]; then
  system
fi

HomeManagerProfile="/nix/var/nix/profiles/per-user/$USER/home-manager"
currentHomeManagerDrv="$(nix-store --query --deriver "$HomeManagerProfile")"
newHomeManagerDrv="$(nix-instantiate ci.nix -A home-manager 2> /dev/null)"
if ! [[ "$currentHomeManagerDrv" == "$newHomeManagerDrv" ]]; then
  echo "Rebuilding home-manager..."
  home-manager switch
else
  echo "No changes to home-manager. Not rebuilding."
fi

popd > /dev/null || exit
