with import <nixpkgs> { };
let
  sources = import ./nix/sources.nix;

  devshell = import "${sources.devshell}/nix/overlay.nix";

  hm-overlay = self: super: {
    home-manager = super.callPackage "${sources.home-manager}/home-manager" { };
  };

  pkgs = import <nixpkgs> {
    inherit system;
    overlays = [
      devshell
      hm-overlay
    ];
  };


in
pkgs.mkDevShell.fromTOML ./devshell.toml
