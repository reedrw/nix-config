{config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  nix-colors = import sources.nix-colors { };
in
{
  imports = [ nix-colors.homeManagerModule ];

  colorScheme = nix-colors.colorSchemes.material-darker;
}
