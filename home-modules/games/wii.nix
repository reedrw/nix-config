{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dolphin-emu
    (mullvadExclude wheel-wizard)
  ];
}
