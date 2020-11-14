let

  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs-unstable;


in
{

  t400 = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-t400/configuration.nix; }).system;
  t520 = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-t520/configuration.nix; }).system;
  desktop = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-desktop/configuration.nix; }).system;

}
