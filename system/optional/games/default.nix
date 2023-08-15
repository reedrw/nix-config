{ inputs, config, lib, pkgs, ... }:
let
  components = lib.importJSON ./components.json;
  aaglPkgs = inputs.aagl.packages.x86_64-linux;
  # aaglPkgs = import /home/reed/files/aagl-gtk-on-nix;

  aagl-unwrapped = aaglPkgs.anime-game-launcher.unwrapped;
  hrl-unwrapped = aaglPkgs.honkers-railway-launcher.unwrapped;

  # aagl = with aaglPkgs.anime-game-launcher; override {
  #   unwrapped = (unwrapped.overrideAttrs (old: rec {
  #     src = inputs.an-anime-game-launcher;
  #     version = inputs.an-anime-game-launcher.shortRev;
  #     cargoDeps = pkgs.rustPlatform.importCargoLock {
  #       lockFile = "${src}/Cargo.lock";
  #       outputHashes = {
  #         "anime-game-core-1.12.1" = "sha256-a0ySBB4XqrP1JYkaAHS81cRiQBKS+B4P4WSm/cEvnMw=";
  #         "anime-launcher-sdk-1.7.2" = "sha256-b7yJa9i8lfBWt7KxqGhIgMxPN6nA1KDKmlfnEXZkEcI=";
  #       };
  #     };
  #   })).override {
  #     customIcon = builtins.fetchurl components.aagl.icon;
  #   };
  # };

  aagl = aaglPkgs.anime-game-launcher.override {
    unwrapped = aagl-unwrapped.override {
      customIcon = builtins.fetchurl components.aagl.icon;
    };
  };

  # hrl = with aaglPkgs.honkers-railway-launcher; override {
  #   unwrapped = (unwrapped.overrideAttrs (old: rec {
  #     src = inputs.the-honkers-railway-launcher;
  #     version = inputs.the-honkers-railway-launcher.shortRev;
  #     cargoDeps = pkgs.rustPlatform.importCargoLock {
  #       lockFile = "${src}/Cargo.lock";
  #       outputHashes = {
  #         "anime-game-core-1.12.6" = "sha256-wRlI3q7Irlkt21Ej2cFqNzOfa4/CXYzweNHc59Bto1w=";
  #         "anime-launcher-sdk-1.7.7" = "sha256-/NmisW/xAE2LlY+Kj/+DLXsryBwuvcatEUVdGq2EAw8=";
  #       };
  #     };
  #   })).override {
  #     customIcon = builtins.fetchurl components.hrl.icon;
  #   };
  # };

  hrl = aaglPkgs.honkers-railway-launcher.override {
    unwrapped = hrl-unwrapped.override {
      customIcon = builtins.fetchurl components.hrl.icon;
    };
  };

  mve = lib.optionalString config.services.mullvad-vpn.enable "mullvad-exclude";

  anime-game-launcher = with pkgs; let
    wrapper = aliasToPackage { anime-game-launcher = ''${mve} ${aagl}/bin/anime-game-launcher "$@"''; };
  in symlinkJoin {
    inherit (aagl-unwrapped) pname version name;
    paths = with aagl.passthru; [ wrapper icon desktopEntry ];
  };

  honkers-railway-launcher = with pkgs; let
    wrapper = aliasToPackage { honkers-railway-launcher = ''${mve} ${hrl}/bin/honkers-railway-launcher "$@"''; };
  in symlinkJoin {
    inherit (hrl-unwrapped) pname version name;
    paths = with hrl.passthru; [ wrapper icon desktopEntry ];
  };
in
{
  imports = [
    inputs.aagl.nixosModules.default
  ];

  # nixpkgs.overlays = [ aaglPkgs.overlay ];

  programs.steam = with pkgs; {
    enable = true;
    package = steam.override {
      extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package ];
      extraPkgs = pkgs: [ mangohud ];
    };
  };

  networking.mihoyo-telemetry.block = true;

  environment.systemPackages = with pkgs; [
    r2mod_cli
    nurPkgs.genshin-account-switcher
    anime-game-launcher
    (aliasToPackage {
      gsi = "anime-game-launcher --just-run-game";
      gas = ''genshin-account-switcher "$@"'';
    })
    # honkers-railway-launcher
    # (aliasToPackage {
    #   hsr = "honkers-railway-launcher --run-game";
    # })
  ];

}
