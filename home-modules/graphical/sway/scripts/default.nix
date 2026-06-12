{ lib, pkgs, osConfig, ... }:

{
  lib.scripts = lib.genAttrs [
    "brightness"
    "dwebp-serv"
    "load-layouts"
    "record"
    "select-term"
    "solaar"
    "toggle-touchpad"
    "volume"
  ] (name: pkgs.writeNixShellScript name <| builtins.readFile (./. + "/${name}.sh"))
  // {
    clipboard-clean = let
      unalix = pkgs.callPackage ./unalix { };
    in pkgs.writeShellApplication {
      name = "clipboard-clean";
      runtimeInputs = with pkgs; [
        coreutils
        wl-clipboard
        (python3.withPackages (_: [ unalix ]))
      ];
      text = builtins.readFile ./clipboard-clean.sh;
    };

    droidcam-fix = pkgs.writeShellApplication {
      name = "droidcam-fix";
      runtimeInputs = [ osConfig.boot.kernelPackages.v4l2loopback.bin ];
      text = builtins.readFile ./droidcam-fix.sh;
    };

    mpv-dnd = let
      unwrapped = pkgs.writeNixShellScript "mpv-dnd" <| builtins.readFile ./mpv-dnd.sh;
      chatApps = [
        "telegram-desktop"
        "discord"
      ];
    in pkgs.writeShellScriptBin "mpv-dnd" ''
      ${lib.getExe unwrapped} ${builtins.concatStringsSep " " chatApps} "$@"
    '';
  };
}
