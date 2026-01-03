{ pkgs, ... }:

{
  home.packages = with pkgs; [
    duckstation
    pcsx2
  ];
}
