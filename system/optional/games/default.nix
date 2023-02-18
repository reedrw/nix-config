{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { inherit pkgs; };

  aagl-gtk-unwrapped = aagl-gtk-on-nix.an-anime-game-launcher-gtk-unwrapped-git;

  aagl-gtk-custom = aagl-gtk-on-nix.an-anime-game-launcher-gtk.override {
    an-anime-game-launcher-gtk-unwrapped = with (lib.importJSON ./components.json); aagl-gtk-unwrapped.override {
      customDxvk = dxvk;
      customGEProton = GEProton;
      customSoda = soda;
      customLutris = lutris;
      customWineGEProton = wineGE;
      customIcon = builtins.fetchurl icon;
    };
  };

in
{
  imports = [
    aagl-gtk-on-nix.module
  ];

  programs.steam = {
    enable = true;
    package = ((pkgs.importNixpkgs sources.nixpkgs-216883).steam.override {
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
