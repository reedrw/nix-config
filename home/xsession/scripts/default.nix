{ lib, pkgs, ... }:

with pkgs;
lib.genAttrs [
  "dwebp-serv"
  "keybinds"
  "load-layouts"
  "pause-suspend"
  "record"
  "select-term"
  "toggle-touchpad"
  "volume"
] (name: writeNixShellScript name (builtins.readFile (./. + "/${name}.sh"))) // {
  clipboard-clean = let
    unalix = callPackage ./unalix { };
  in writeShellApplication {
    name = "clipboard-clean";
    runtimeInputs = [
      coreutils
      xclip
      (python3.withPackages(ps: [ unalix ]))
    ];
    text = (builtins.readFile ./clipboard-clean.sh);
  };

  mpv-dnd = let
    unwrapped = writeNixShellScript "mpv-dnd" (builtins.readFile ./mpv-dnd.sh);
    # Window classes to be suspended while mpv is the active window
    chatApps = [
      "TelegramDesktop"
      "vesktop"
    ];
  in pkgs.writeShellScriptBin "mpv-dnd" ''
    ${lib.getExe unwrapped} ${builtins.concatStringsSep " " chatApps} "$@"
  '';
}
