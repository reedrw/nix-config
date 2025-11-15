{ pkgs, ... }:

{
  imports = [
    ./discord
    ./weechat
    ./telegram.nix
  ];

  home.packages = with pkgs; [
    signal-desktop
  ];
}
