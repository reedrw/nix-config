{ pkgs, lib, config, ...}:
let
  sources = lib.importJSON ./sources.json;
in
{
  home.packages = with pkgs; [
    github-cli
  ];

  home.file.".local/share/gh/extensions/gh-copilot/gh-copilot".source = let
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

  home.file.".local/share/gh/extensions/gh-copilot/manifest.yml".source = pkgs.writeText "manifest.yml" (builtins.toJSON {
    inherit (sources) tag;
    owner = "github";
    name = "gh-copilot";
    host = "github.com";
    ispinned = true;
    path = config.home.homeDirectory + "/.local/share/gh/extensions/gh-copilot/gh-copilot";
  });

}
