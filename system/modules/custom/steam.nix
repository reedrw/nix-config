{ config, pkgs, lib, ... }:

let
  cfg = config.custom.steam;
  steam-custom = with pkgs; steam.override {
    extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package];
    extraPkgs = pkgs: [ mangohud ];
    extraEnv = {
      # https://github.com/ValveSoftware/Source-1-Games/issues/5043
      LD_PRELOAD = "$LD_PRELOAD:/run/current-system/sw/lib/libtcmalloc_minimal.so";
    };
  };
in
{
  options.custom.steam = {
    enable = lib.mkEnableOption "Steam";

    mullvad-exclude = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Exclude Steam from Mullvad VPN";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      package = with pkgs; emptyDirectory // {
        override = (x: optionalApply cfg.mullvad-exclude mullvadExclude steam-custom // {
          run = steam-custom.run;
        });
      };
    };
    # https://github.com/ValveSoftware/Source-1-Games/issues/5043
    environment.systemPackages = with pkgs; [
      pkgsi686Linux.gperftools
      (pkgs.adwsteamgtk or pinned.adwsteamgtk.v0_6_9)
    ];
  };
}
