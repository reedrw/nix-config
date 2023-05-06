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
    pkgs.an-anime-game-launcher-unwrapped.overrideAttrs ( old:
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
    else pkgs.an-anime-game-launcher-unwrapped;
in
{
  imports = [
    aaglPkgs.module
  ];

  nixpkgs.overlays = [ aaglPkgs.overlay ];

  programs.steam = with pkgs; {
    enable = true;
    package = steam.override {
      extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package ];
      extraPkgs = pkgs: [
        xdg-user-dirs
        mangohud
      ];
      # https://github.com/NixOS/nixpkgs/issues/230246
      extraProfile = ''
        export GSETTINGS_SCHEMA_DIR="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}/glib-2.0/schemas/"
      '';
    };
  };

  programs.an-anime-game-launcher = {
    enable = true;
    package = with components; pkgs.an-anime-game-launcher.override {
      an-anime-game-launcher-unwrapped = aagl-unwrapped.override {
        customIcon = builtins.fetchurl icon;
      };
    };
  };

  programs.the-honkers-railway-launcher = {
    enable = true;
    package = pkgs.the-honkers-railway-launcher;
  };

  environment.systemPackages = with pkgs; [
    r2mod_cli
    nurPkgs.genshin-account-switcher
    (aliasToPackage {
      gsi = "anime-game-launcher --run-game";
      gas = ''genshin-account-switcher "$@"'';
      hsr = "honkers-railway-launcher --run-game";
    })
  ];

}
