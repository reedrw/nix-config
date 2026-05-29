{ pkgs, ... }:

{
  home.packages = with pkgs; [
    xdcc-dl
  ];
}
