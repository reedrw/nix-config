{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aaglPkgs = import sources.aagl-gtk-on-nix { inherit pkgs; };

  components = lib.importJSON ./components.json;

  aagl-unwrapped = aaglPkgs.an-anime-game-launcher-unwrapped;

in
{
  imports = [
    aaglPkgs.module
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
    package = with components; aaglPkgs.an-anime-game-launcher.override {
      an-anime-game-launcher-unwrapped = aagl-unwrapped.override {
        customIcon = builtins.fetchurl icon;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    r2mod_cli
    nurPkgs.genshin-account-switcher
    (aliasToPackage {
      gsi = "anime-game-launcher --run-game";
      gas = ''genshin-account-switcher "$@"'';
    })
  ];

}
