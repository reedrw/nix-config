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

  lib.scripts.rofi-comma = pkgs.writeNixShellScript "rofi-comma" <| builtins.readFile ./rofi-comma.sh;

  custom.persistence.files = [
    ".cache/rofi-2.sshcache"
    ".cache/rofi-3.runcache"
    ".cache/rofi-4.runcache"
    ".cache/rofi-entry-history.txt"
    ".cache/rofi3.druncache"
  ];
}
