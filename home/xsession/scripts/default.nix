pkgs: {
  dwebp-serv = pkgs.writeNixShellScript "dwebp-serv" (builtins.readFile ./dwebp-serv.sh);
  keybinds = pkgs.writeNixShellScript "keybinds" (builtins.readFile ./keybinds.sh);
  load-layouts = pkgs.writeNixShellScript "load-layouts" (builtins.readFile ./load-layouts.sh);
  mpv-dnd = pkgs.writeNixShellScript "mpv-dnd" (builtins.readFile ./mpv-dnd.sh);
  pause-suspend = pkgs.writeNixShellScript "pause-suspend" (builtins.readFile ./pause-suspend.sh);
  record = pkgs.writeNixShellScript "record" (builtins.readFile ./record.sh);
  select-term = pkgs.writeNixShellScript "select-term" (builtins.readFile ./select-term.sh);
  toggle-touchpad = pkgs.writeNixShellScript "toggle-touchpad" (builtins.readFile ./toggle-touchpad.sh);
  volume = pkgs.writeNixShellScript "volume" (builtins.readFile ./volume.sh);

  clipboard-clean = let
    sources = import ./clipboard-clean-patches/nix/sources.nix { };
    unalix = pkgs.python3Packages.buildPythonPackage {
      name = "Unalix";
      src = sources.Unalix;

      patches = [ ./clipboard-clean-patches/update.patch ];

      doCheck = false;
    };
    in pkgs.writeShellApplication {
    name = "clipboard-clean";
    runtimeInputs = with pkgs; [
      coreutils
      xclip
      (python3.withPackages(ps: [ unalix ]))
    ];
    text = (builtins.readFile ./clipboard-clean.sh);
  };
}
