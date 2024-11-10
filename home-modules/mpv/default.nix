{ pkgs, ... }:

let
  sources = import ./nix/sources.nix { };

  mkPlugin = path: let
    name = (builtins.baseNameOf path);
  in pkgs.runCommandNoCC name {
    passthru.scriptName = name;
  } ''
    mkdir -p $out/share/mpv/scripts
    cp ${path} $out/share/mpv/scripts/${name}
  '';
in
{
  programs.mpv = {
    package = pkgs.mpv.override {
      scripts = with pkgs.mpvScripts; [
        (mkPlugin "${sources.mpv-scripts}/clipshot.lua")
        (mkPlugin "${sources.vanilla-osc}/player/lua/osc.lua")
        mpris
        mpv-webm
        thumbfast
      ];
    };
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
}
