{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aaglPkgs = import sources.aagl-gtk-on-nix;

  components = lib.importJSON ./components.json;

  aagl-unwrapped =
    let
      fromLocal = false;
    in with sources.an-anime-game-launcher;
    if fromLocal then
    aaglPkgs.an-anime-game-launcher-unwrapped.overrideAttrs ( old:
      rec {
        src = /home/reed/files/an-anime-game-launcher;
        version = with pkgs; let
          versionFile = stdenv.mkDerivation {
            name = "ver";
            inherit src;
            buildInputs = [ git ];
            buildPhase = "git rev-parse HEAD > $out";
          };
        in shortenRev (builtins.readFile versionFile);
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
        };
      })
    else aaglPkgs.an-anime-game-launcher-unwrapped;
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
