{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { inherit pkgs; };

  aagl-gtk-unwrapped = aagl-gtk-on-nix.an-anime-game-launcher-gtk-unwrapped-git;

  aagl-gtk-custom = aagl-gtk-on-nix.an-anime-game-launcher-gtk.override {
    an-anime-game-launcher-gtk-unwrapped =
    let
      components = lib.importJSON ./components.json;
    in
    aagl-gtk-unwrapped.override {
      customDxvk = components.dxvk;
      customGEProton = components.GEProton;
      customIcon = builtins.fetchurl (lib.importJSON ./icon.json);
    };
  };

in
{
  imports = [
    aagl-gtk-on-nix.module
  ];

  programs.steam = {
    enable = true;
    package = (pkgs.steam.override {
      extraLibraries = pkgs: [ config.hardware.opengl.package ];
      extraPkgs = pkgs: with pkgs; [
        mangohud
      ];
    });
  };

  programs.an-anime-game-launcher = {
    enable = true;
    package = aagl-gtk-custom;
  };

  environment.systemPackages = with pkgs; [
    (aliasToPackage {
      gsi = "anime-game-launcher --run-game";
    })
  ];

}
