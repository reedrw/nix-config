{ inputs, config, lib, pkgs, ... }:
let
  components = lib.importJSON ./components.json;
  aaglPkgs = inputs.aagl.packages.x86_64-linux;

  aagl-unwrapped = aaglPkgs.anime-game-launcher.unwrapped;

  aagl = aaglPkgs.anime-game-launcher.override {
    unwrapped = aagl-unwrapped.override {
      customIcon = builtins.fetchurl components.aagl.icon;
    };
  };

  anime-game-launcher = pkgs.mullvadExclude aagl;
in
{
  imports = [
    inputs.aagl.nixosModules.default
  ];

  programs.steam = with pkgs; {
    enable = true;
    package = let
      steam-custom = steam.override {
        extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package ];
        extraPkgs = pkgs: [ mangohud ];
      };
      steam-mve = mullvadExclude steam-custom;
    in emptyDirectory // {
      override = (x: steam-mve // {
        run = steam-custom.run;
      });
    };
  };

  networking.mihoyo-telemetry.block = true;

  environment.systemPackages = with pkgs; [
    r2mod_cli
    anime-game-launcher
    (aliasToPackage {
      gsi = "anime-game-launcher --just-run-game";
      gas = ''genshin-account-switcher "$@"'';
    })
  ];

}
