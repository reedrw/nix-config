{ config, lib, pkgs, ... }:
{
  imports = [ ./base16-nix/base16.nix ];

  # Base16 colorschemes
  # ./base16-nix/schemes.json
  themes.base16 = {
    enable = true;
    scheme = "materialtheme";
    variant = "material-darker";
  };

}
