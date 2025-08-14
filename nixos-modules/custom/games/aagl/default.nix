{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.custom.aagl;
  customIcon = builtins.fetchurl <| lib.importJSON ./icon.json;
  aaglPkgs = inputs.aagl.packages.x86_64-linux;
in
{
  options.custom.aagl = {
    enable = lib.mkEnableOption "enable AAGL";
    mullvad-exclude = lib.mkEnableOption "exclude AAGL from Mullvad VPN";
  };

  config = lib.mkIf cfg.enable {
    programs.anime-game-launcher = {
      enable = true;
      package = with pkgs; let
        aagl = aaglPkgs.anime-game-launcher.override (old: {
          unwrapped = (old.unwrapped.override {
            inherit customIcon;
          });
        });
      in if cfg.mullvad-exclude then mullvadExclude aagl else aagl;
    };

    environment.systemPackages = with pkgs; [
      (aliasToPackage {
        gsi = "${config.programs.anime-game-launcher.package}/bin/anime-game-launcher --just-run-game";
      })
    ];
  };
}
