#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq nix-build-uncached

case $1 in
  system)
    nix-build-uncached --keep-going \
      -I nixos-config=./system/$machine/configuration.nix \
      -I nixos-hardware="$(jq -r '.["nixos-hardware"].url' ./nix/sources.json)" \
      -I nixpkgs="$(jq -r '.["nixpkgs-unstable"].url' ./nix/sources.json)" \
      -I nur="$(jq -r '.["NUR"].url' ./nix/sources.json)" \
      '<nixpkgs/nixos>' -A system --no-out-link || \
      exit 1
  ;;
  home-manager)
    nix-build-uncached --keep-going \
      -I home-manager="$(jq -r '.["home-manager"].url' ./nix/sources.json)" \
      -I nixpkgs="$(jq -r '.["nixpkgs-unstable"].url' ./nix/sources.json)" \
      '<home-manager/home-manager/home-manager.nix>' \
      --attr activationPackage \
      --argstr confPath "$(readlink -f ./home.nix)" \
      --no-out-link || \
      exit 1
  ;;
esac

