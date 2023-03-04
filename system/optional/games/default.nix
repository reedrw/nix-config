{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { inherit pkgs; };

  aagl-unwrapped = aagl-gtk-on-nix.an-anime-game-launcher-unwrapped;

  aagl-gtk-custom = aagl-gtk-on-nix.an-anime-game-launcher.override {
    an-anime-game-launcher-unwrapped = with (lib.importJSON ./components.json); aagl-unwrapped.override {
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

  programs.steam = with pkgs; {
    enable = true;
    package = steam.override {
      extraLibraries = pkgs: [ config.hardware.opengl.package ];
      extraPkgs = pkgs: with pkgs; [
        mangohud
      ];
    };
  };

  programs.an-anime-game-launcher = {
    enable = true;
    package = aagl-gtk-custom;
  };

  environment.systemPackages = with pkgs; [
    r2mod_cli
    nur.repos.reedrw.genshin-account-switcher
    (aliasToPackage {
      gsi = "anime-game-launcher --run-game";
      gas = ''genshin-account-switcher "$@"'';
    })
  ];

}
