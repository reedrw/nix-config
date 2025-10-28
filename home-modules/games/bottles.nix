{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bottles
    ludusavi
  ];
}
