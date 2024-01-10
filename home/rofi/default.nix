{ config, pkgs, ... }:
let
  roficomma = pkgs.writeNixShellScript "roficomma" (builtins.readFile ./roficomma.sh);
in
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

  xdg.configFile = with pkgs; {
    "rofi/roficomma.sh".source = "${binPath roficomma}";
  };
}
