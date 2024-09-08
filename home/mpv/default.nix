{ config, pkgs, lib, ... }:

let
  plugins = (import ./nix/sources.nix { }) // lib.packagesFromDirectoryRecursive {
    callPackage = pkgs.callPackage;
    directory = ./plugins;
  };
in
{
  programs.mpv = {
    enable = true;
    config = {
      profile = "gpu-hq";
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      osc = "no";
      volume = 70;
      screenshot-directory = "~/";
    };
  };
  xdg.configFile = {
    "mpv/scripts/clipshot.lua".source = "${plugins.mpv-scripts}/clipshot.lua";
    "mpv/scripts/webm.lua".source = "${plugins.mpv-webm}/build/webm.lua";
    "mpv/scripts/thumbfast.lua".source = "${plugins.thumbfast}/thumbfast.lua";
    "mpv/scripts/osc.lua".source = "${plugins.vanilla-osc}/player/lua/osc.lua";
  };
}
