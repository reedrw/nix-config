{ config, lib, pkgs, ... }:
let
  sources = import ../../functions/sources.nix { sourcesFile = ./nix/sources.json; };

  base16 = pkgs.stdenvNoCC.mkDerivation rec {
    name = "base16-nix";

    src = sources.base16-nix;

    patches = [ ./update-base16.patch ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out
      cp -rv ./ $out
    '';

  };

in
{
  imports = [ "${sources.base16-nix}/base16.nix" ];

  # Base16 colorschemes
  # https://github.com/atpotts/base16-nix/blob/master/schemes.json
  themes.base16 = {
    enable = true;
    scheme = "tomorrow";
    variant = "tomorrow-night";
  };

}
