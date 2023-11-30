{ config, pkgs, lib, ... }:

let
  cfg = config.custom.steam;
  steam-custom = with pkgs; steam.override {
    extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package ];
    extraPkgs = pkgs: [ mangohud ];
  };
in
{
  options.custom.steam = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam";
    };

    mullvad-exclude = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Exclude Steam from Mullvad VPN";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      package = with pkgs; if cfg.mullvad-exclude then
        emptyDirectory // {
          override = (x: mullvadExclude steam-custom // {
          run = steam-custom.run;
        });
      }
      else steam-custom;
    };
  };
}
