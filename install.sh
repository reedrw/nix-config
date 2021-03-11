#! /usr/bin/env nix-shell
#! nix-shell -i bash

if [[ -n "$SUDO_ASKPASS" ]]; then
  sudo="sudo -A"
fi

host="$(hostname)"
dir="$(dirname "$0")"

pushd "$dir" > /dev/null || exit

HomeManagerURL="$(jq -r '.["home-manager"].url' ./nix/sources.json)"
nixpkgsURL="$(jq -r '.["nixpkgs"].url' ./nix/sources.json)"
nurURL="$(jq -r '.["NUR"].url' ./nix/sources.json)"
NixOShardwareURL="$(jq -r '.["nixos-hardware"].url' ./nix/sources.json)"

installedHomeManager="$(nix-channel --list | grep "home-manager " | cut -d' ' -f2-)"
if [[ "$installedHomeManager" != "$HomeManagerURL" ]]; then
  echo "Installing pinned home-manager..."
  nix-channel --add "$HomeManagerURL" home-manager
  nix-channel --update
fi

installedNixpkgs="$($sudo nix-channel --list | grep "nixos " | cut -d' ' -f2-)"
if [[ "$installedNixpkgs" != "$nixpkgsURL" ]]; then
  echo "Installing pinned nixpkgs..."
  sudo nix-channel --add "$nixpkgsURL" nixos
  sudo nix-channel --update
  echo "Updating search cache..."
  nix search -u > /dev/null
fi

installedNixOShardware="$($sudo nix-channel --list | grep "nixos-hardware " | cut -d' ' -f2-)"
if [[ "$installedNixOShardware" != "$NixOShardwareURL" ]]; then
  echo "Installing pinned nixos-hardware..."
  sudo nix-channel --add "$NixOShardwareURL" nixos-hardware
  sudo nix-channel --update
fi

installedNUR="$($sudo nix-channel --list | grep "nur " | cut -d' ' -f2-)"
if [[ "$installedNUR" != "$nurURL" ]]; then
  echo "Installing pinned NUR..."
  sudo nix-channel --add "$nurURL" nur
  sudo nix-channel --update
fi

system(){
  # if the hostname matches a saved configuration.nix
  if [[ -d "./system/$host" ]]; then
    currentSystemDrv="$(nix-store --query --deriver "$systemProfile")"
    newSystemDrv="$(nix-instantiate ci.nix -A "$host" 2> /dev/null)"
    # compare deriver of current and new system builds, if different, rebuild
    if ! [[ "$currentSystemDrv" == "$newSystemDrv" ]]; then
      echo "Rebuilding NixOS..."
      sudo nixos-rebuild switch -I nixos-config="$dir"/system/"$host"/configuration.nix
    else
      echo "No changes to system. Not rebuilding."
    fi
  else
    echo "Rebuilding NixOS..."
    sudo nixos-rebuild switch
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
