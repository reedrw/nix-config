#! /usr/bin/env nix-shell
#! nix-shell -i bash

HomeManagerURL="$(jq -r '.["home-manager"].url' ./nix/sources.json)"
nixpkgsURL="$(jq -r '.["nixpkgs-unstable"].url' ./nix/sources.json)"
nurURL="$(jq -r '.["NUR"].url' ./nix/sources.json)"
NixOShardwareURL="$(jq -r '.["nixos-hardware"].url' ./nix/sources.json)"

installedHomeManager="$(nix-channel --list | grep "home-manager " | cut -d' ' -f2-)"
if [[ "$installedHomeManager" != "$HomeManagerURL" ]]; then
  echo "Installing pinned home-manager..."
  nix-channel --add "$HomeManagerURL" home-manager
  nix-channel --update
fi

installedNixpkgs="$(sudo nix-channel --list | grep "nixos " | cut -d' ' -f2-)"
if [[ "$installedNixpkgs" != "$nixpkgsURL" ]]; then
  echo "Installing pinned nixpkgs..."
  sudo nix-channel --add "$nixpkgsURL" nixos
  sudo nix-channel --update
fi

installedNixOShardware="$(sudo nix-channel --list | grep "nixos-hardware " | cut -d' ' -f2-)"
if [[ "$installedNixOShardware" != "$NixOShardwareURL" ]]; then
  echo "Installing pinned nixos-hardware..."
  sudo nix-channel --add "$NixOShardwareURL" nixos-hardware
  sudo nix-channel --update
fi

installedNUR="$(sudo nix-channel --list | grep "nur " | cut -d' ' -f2-)"
if [[ "$installedNUR" != "$nurURL" ]]; then
  echo "Installing pinned NUR..."
  sudo nix-channel --add "$nurURL" nur
  sudo nix-channel --update
fi

echo "Rebuilding NixOS..."
sudo nixos-rebuild switch --upgrade
echo "Rebuilding home-manager..."
home-manager switch
echo "Updating user nix-env..."
nix-env -u
echo "Updating search cache..."
nix search -u > /dev/null
echo "Optimizing nix store..."
nix-store --optimise --verbose

