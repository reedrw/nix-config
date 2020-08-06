{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

  base16-nix = sources.base16-nix;

in
{
  imports = [ "${base16-nix}/base16.nix" ];

  # Base16 colorschemes
  # https://github.com/atpotts/base16-nix/blob/master/schemes.json
  themes.base16 = {
    enable = true;
    scheme = "onedark";
    variant = "onedark";
  };

}

