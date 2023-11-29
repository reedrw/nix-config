{ inputs, config, lib, pkgs, ... }:
let
  components = lib.importJSON ./components.json;
  aaglPkgs = inputs.aagl.packages.x86_64-linux;
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

  programs.anime-game-launcher = {
    enable = true;
    package = pkgs.mullvadExclude (aaglPkgs.anime-game-launcher.override (old: {
      unwrapped = old.unwrapped.override {
        customIcon = builtins.fetchurl components.aagl.icon;
      };
    }));
  };

  environment.systemPackages = with pkgs; [
    r2mod_cli
    (aliasToPackage {
      gsi = "${config.programs.anime-game-launcher.package}/bin/anime-game-launcher --just-run-game";
    })
  ];

}
