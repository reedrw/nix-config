{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.custom.hrl;
  customIcon = builtins.fetchurl (lib.importJSON ./icon.json);
  aaglPkgs = inputs.aagl.packages.x86_64-linux;
in
{
  options.custom.hrl = {
    enable = lib.mkEnableOption "enable HRL";
    mullvad-exclude = lib.mkEnableOption "exclude HRL from Mullvad VPN";
  };

  config = lib.mkIf cfg.enable {
    programs.honkers-railway-launcher = {
      enable = true;
      package = with pkgs; let
        hrl = aaglPkgs.honkers-railway-launcher.override (old: {
          unwrapped = old.unwrapped.override {
            inherit customIcon;
          };
        });
      in if cfg.mullvad-exclude then mullvadExclude hrl else hrl;
    };

    environment.systemPackages = with pkgs; [
      (aliasToPackage {
        hrl = "${config.programs.honkers-railway-launcher.package}/bin/honkers-railway-launcher --run-game";
      })
    ];
  };
}
