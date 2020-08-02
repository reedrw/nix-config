#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

HomeManagerURL="$(jq -r '.["home-manager"].url' ./nix/sources.json)"
nixpkgsURL="$(jq -r '.["nixpkgs-unstable"].url' ./nix/sources.json)"
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

echo "Rebuilding NixOS..."
sudo nixos-rebuild switch --upgrade
echo "Rebuilding home-manager..."
home-manager switch
echo "Updating user nix-env..."
nix-env -u
