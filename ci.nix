{
  sources ? import ./nix/sources.nix { },
  pkgs ? import sources.nixpkgs { config = import ./config.nix; },
  lib ? pkgs.lib
}:
let
  systemDir = builtins.readDir ./system;
  systemConfigs = (builtins.partition
    (x: lib.strings.hasSuffix ".nix" x)
    (builtins.attrNames systemDir)
  ).right;
  systemConfigsImported = lib.attrsets.genAttrs
    (map (x: builtins.replaceStrings [".nix"] [""] x) systemConfigs)
    (name: let
        configuration = import (./system + "/${name}.nix");
      in (import "${sources.nixpkgs}/nixos" { inherit configuration; }).system);
in
systemConfigsImported // {
  home-manager = (import "${sources.home-manager}/home-manager/home-manager.nix" {
    inherit pkgs;
    confPath = ./home.nix;
  }).activationPackage;
}
