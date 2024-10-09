{ lib, pkgs, osConfig, ... }:

{
  lib.scripts = lib.genAttrs [
    "brightness"
    "dwebp-serv"
    "keybinds"
    "load-layouts"
    "pause-suspend"
    "record"
    "select-term"
    "toggle-touchpad"
    "volume"
  ] (name: pkgs.writeNixShellScript name (builtins.readFile (./. + "/${name}.sh"))) // {
    clipboard-clean = let
      unalix = pkgs.callPackage ./unalix { };
    in pkgs.writeShellApplication {
      name = "clipboard-clean";
      runtimeInputs = with pkgs; [
        coreutils
        xclip
        (python3.withPackages(ps: [ unalix ]))
      ];
      text = (builtins.readFile ./clipboard-clean.sh);
    };

    droidcam-fix = pkgs.writeShellApplication {
      name = "droidcam-fix";
      runtimeInputs = [ osConfig.boot.kernelPackages.v4l2loopback.bin ];
      text = (builtins.readFile ./droidcam-fix.sh);
    };

    mpv-dnd = let
      unwrapped = pkgs.writeNixShellScript "mpv-dnd" (builtins.readFile ./mpv-dnd.sh);
      # Window classes to be suspended while mpv is the active window
      chatApps = [
        "TelegramDesktop"
        "vesktop"
      ];
    in pkgs.writeShellScriptBin "mpv-dnd" ''
      ${lib.getExe unwrapped} ${builtins.concatStringsSep " " chatApps} "$@"
    '';
  };
}
