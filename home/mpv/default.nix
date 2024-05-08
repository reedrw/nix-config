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
    };
  };
  xdg.configFile = {
    "mpv/scripts/clipshot.lua".source = "${plugins.mpv-scripts}/clipshot.lua";
    "mpv/scripts/webm.lua".source = "${plugins.mpv-webm}/build/webm.lua";
    "mpv/scripts/mpv_thumbnail_script_client_osc.lua".source = "${plugins.mpv_thumbnail_script}/mpv_thumbnail_script_client_osc.lua";
    "mpv/scripts/mpv_thumbnail_script_server.lua".source = "${plugins.mpv_thumbnail_script}/mpv_thumbnail_script_server.lua";
    "mpv/script-opts/mpv_thumbnail_script.conf".text = ''
      mpv_no_sub=yes
      cache_directory=${config.home.homeDirectory}/.cache/mpv/my_mpv_thumbnails
      autogenerate_max_duration=0
    '';
  };
}
