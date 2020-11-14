{ config, lib, pkgs, ... }:
let

  sources = import ./nix/sources.nix;

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
