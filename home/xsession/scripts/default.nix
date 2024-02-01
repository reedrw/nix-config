{ lib, pkgs, ... }:

with pkgs;
{
  dwebp-serv = writeNixShellScript "dwebp-serv" (builtins.readFile ./dwebp-serv.sh);
  keybinds = writeNixShellScript "keybinds" (builtins.readFile ./keybinds.sh);
  load-layouts = writeNixShellScript "load-layouts" (builtins.readFile ./load-layouts.sh);
  pause-suspend = writeNixShellScript "pause-suspend" (builtins.readFile ./pause-suspend.sh);
  record = writeNixShellScript "record" (builtins.readFile ./record.sh);
  select-term = writeNixShellScript "select-term" (builtins.readFile ./select-term.sh);
  toggle-touchpad = writeNixShellScript "toggle-touchpad" (builtins.readFile ./toggle-touchpad.sh);
  volume = writeNixShellScript "volume" (builtins.readFile ./volume.sh);

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
