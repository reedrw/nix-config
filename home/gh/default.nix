{ pkgs, lib, config, ...}:
let
  sources = lib.importJSON ./sources.json;
in
{
  home.packages = with pkgs; [
    github-cli
  ];

  home.file."${pkgs.removeHomeDirPrefix config.xdg.dataHome}/gh/extensions/gh-copilot/gh-copilot".source = let
    binary = import <nix/fetchurl.nix> {
      inherit (sources) url sha256;
    };
  in pkgs.stdenvNoCC.mkDerivation {
    name = "gh-copilot";

    src = pkgs.emptyDirectory;

    installPhase = ''
      cp ${binary} $out
      chmod +x $out
    '';
  };

  home.file.".config/gh-copilot/config.yml".source = builtins.toFile "config.yml" (builtins.toJSON {
    optional_analytics = false;
  });

  home.file."${pkgs.removeHomeDirPrefix config.xdg.dataHome}/gh/extensions/gh-copilot/manifest.yml".source = builtins.toFile "manifest.yml" (builtins.toJSON {
    inherit (sources) tag;
    owner = "github";
    name = "gh-copilot";
    host = "github.com";
    ispinned = true;
    path = "${config.xdg.dataHome}/gh/extensions/gh-copilot/gh-copilot";
  });

}
