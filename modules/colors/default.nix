{config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  nix-colors = import sources.nix-colors { };
in
with nix-colors;
{
  imports = [ homeManagerModule ];

  colorScheme = colorSchemes.material-darker;
}
