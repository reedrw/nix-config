{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.custom.zzz;
  customIcon = builtins.fetchurl (lib.importJSON ./icon.json);
  aaglPkgs = inputs.aagl.packages.x86_64-linux;
in
{
  options.custom.zzz = {
    enable = lib.mkEnableOption "enable ZZZ";
    mullvad-exclude = lib.mkEnableOption "exclude ZZZ from Mullvad VPN";
  };

  config = lib.mkIf cfg.enable {
    programs.sleepy-launcher = {
      enable = true;
      package = with pkgs; let
        zzz = aaglPkgs.sleepy-launcher.override (old: {
          unwrapped = old.unwrapped.override {
            inherit customIcon;
          };
        });
      in if cfg.mullvad-exclude then mullvadExclude zzz else zzz;
    };

    environment.systemPackages = with pkgs; [
      (aliasToPackage {
        zzz = "${config.programs.sleepy-launcher.package}/bin/sleepy-launcher --run-game";
      })
    ];
  };
}
