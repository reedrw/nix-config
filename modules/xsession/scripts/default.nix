{ pkgs, ... }:
{
  load-layouts = pkgs.writeNixShellScript "load-layouts" (builtins.readFile ./load-layouts.sh);

  mpv-dnd = pkgs.writeNixShellScript "mpv-dnd" (builtins.readFile ./mpv-dnd.sh);

  pause-suspend = pkgs.writeNixShellScript "pause-suspend" (builtins.readFile ./pause-suspend.sh);

  record = pkgs.writeNixShellScript "record.sh" (builtins.readFile ./record.sh);

  selecterm = pkgs.writeNixShellScript "select-term.sh" (builtins.readFile ./select-term.sh);

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

  bwmenu-patched = pkgs.nurPkgs.bitwarden-rofi.overrideAttrs (_: {
    src = pkgs.fetchFromGitHub {
      owner = "mattydebie";
      repo = "bitwarden-rofi";
      rev = "a5f6348fae6a96499a27a25a79f83ed37da81716";
      sha256 = "sha256-QggtjWrt27obx8Igjj2DVtIZ5XLAf/iJSPsUmZkY4Yk=";
    };
    patches = [
      ./bwmenu-patches/copy-totp.patch
      ./bwmenu-patches/fix-quotes.patch
    ];
  });
}
