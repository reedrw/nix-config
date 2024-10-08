{ pkgs, ... }:

{
  imports = [
    ./rofi-askpass.nix
    ./theme.nix
  ];

  programs.rofi = {
    enable = true;
    font = "FantasqueSansM Nerd Font Bold 10";
  };

  lib.scripts.rofi-comma = pkgs.writeNixShellScript "rofi-comma" (builtins.readFile ./rofi-comma.sh);
}
