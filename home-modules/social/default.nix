{ pkgs, ... }:

{
  imports = [
    ./discord.nix
    ./telegram.nix
  ];

  home.packages = with pkgs; [
    signal-desktop
  ];
}
