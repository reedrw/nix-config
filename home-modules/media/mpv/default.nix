{ pkgs, lib, util, config, osConfig, ... }:

let
  sources = (util.importFlake ./plugins).inputs;

  mkPlugin = path: let
    name = builtins.baseNameOf path;
  in pkgs.runCommand name {
    passthru.scriptName = name;
  } ''
    mkdir -p $out/share/mpv/scripts
    cp ${path} $out/share/mpv/scripts/${name}
  '';
in
{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv.override {
      scripts = with pkgs.mpvScripts; [
        (mkPlugin "${sources.mpv-scripts}/clipshot.lua")
        (mkPlugin "${sources.vanilla-osc}/player/lua/osc.lua")
        mpris
        mpv-webm
        thumbfast
      ];
    };
    config = {
      profile = "gpu-hq";
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      osc = "no";
      volume = 70;
      screenshot-directory = "~/";
    };
    bindings = {
      WHEEL_LEFT = "add volume -2";
      WHEEL_RIGHT = "add volume 2";
    };
  };
  services.jellyfin-mpv-shim = {
    enable = osConfig.services.jellyfin.enable;
    package = let
      # Hack workaround for
      # https://github.com/jellyfin/jellyfin-mpv-shim/issues/344
      #
      # Instead of loading session from cred.json, force a CLI interface,
      # and load login information from a file
      package = pkgs.jellyfin-mpv-shim.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          rm jellyfin_mpv_shim/gui_mgr.py
        '';
        propagatedBuildInputs = old.propagatedBuildInputs
        |> lib.flip (lib.foldl' (acc: x: lib.filter (y: !lib.hasInfix x y))) [
          "pillow"
          "pystray"
          "tkinter"
        ] {};
      });
    in pkgs.wrapPackage package (x: ''
      #!${pkgs.runtimeShell}
      loginFile="${osConfig.custom.persistDir}/secrets/jellyfin/login"
      if test -f "\$loginFile"; then
        ${x} "\$@" < "\$loginFile"
      else
        ${x} "\$@"
      fi
    '');
    mpvConfig = config.programs.mpv.config;
    mpvBindings = config.programs.mpv.bindings;
    settings = {
      mpv_ext = true;
      mpv_ext_path = "${config.programs.mpv.package}/bin/mpv";
    };
  };
  systemd.user.services.jellyfin-mpv-shim.Service = {
    ExecSearchPath = "${pkgs.coreutils}/bin";
    ExecStartPre = "sleep 5";
  };
}
