{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dolphin-emu
    wheel-wizard
  ];
}
