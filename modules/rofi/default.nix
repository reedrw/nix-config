{ config, lib, pkgs, ... }:
let
  roficomma = pkgs.writeShellApplication {
    name = "roficomma";
    runtimeInputs = with pkgs; [ nix-index ];
    text = builtins.readFile ./roficomma.sh;
  };
in
{
  imports = [
    ./rofi-askpass.nix
  ];

  programs.rofi = {
    enable = true;
    font = "scientifica 8";
    theme = (
      import ./theme.nix {
        inherit config;
      }
    );
  };

  xdg.configFile = {
    "rofi/roficomma.sh".source = "${roficomma}/bin/roficomma";
  };
}
