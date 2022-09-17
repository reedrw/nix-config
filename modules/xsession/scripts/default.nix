{ pkgs, ... }:
{
  load-layouts = pkgs.writeShellApplication {
    name = "load-layouts.sh";
    runtimeInputs = [ pkgs.wmctrl ];
    text = (builtins.readFile ./load-layouts.sh);
  };

  selecterm = pkgs.writeShellApplication {
    name = "select-term.sh";
    runtimeInputs = [ pkgs.slop ];
    text = (builtins.readFile ./select-term.sh);
  };

  record = pkgs.writeShellApplication {
    name = "record.sh";
    runtimeInputs = with pkgs; [
      slop
      ffmpeg
      libnotify
    ];
    text = (builtins.readFile ./record.sh);
  };

  clipboard-clean = let
    sources = import ./clipboard-clean-patches/nix/sources.nix { };
    unalix = pkgs.python3Packages.buildPythonPackage rec {
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
      (python3.withPackages(ps: with ps; [ unalix ]))
    ];
    text = (builtins.readFile ./clipboard-clean.sh);
  };

  bwmenu-patched = pkgs.nur.repos.reedrw.bitwarden-rofi.overrideAttrs (
    old: rec {
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
    }
  );
}
