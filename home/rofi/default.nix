{ config, pkgs, lib, ... }:

{
  imports = [
    ./rofi-askpass.nix
  ];

  programs.rofi = {
    enable = true;
    font = "FantasqueSansM Nerd Font Bold 10";
    theme = (
      import ./theme.nix {
        inherit config;
      }
    );
  };

  lib.scripts.roficomma = pkgs.writeNixShellScript "roficomma" (builtins.readFile ./roficomma.sh);
}
