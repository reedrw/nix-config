let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs-unstable;

in
{

  nixos-t400 = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-t400/configuration.nix; }).system;
  nixos-t520 = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-t520/configuration.nix; }).system;
  nixos-desktop = (import "${sources.nixpkgs-unstable}/nixos" { configuration = import ./system/nixos-desktop/configuration.nix; }).system;

  home-manager = (import "${sources.home-manager}/home-manager/home-manager.nix" { pkgs = import "${sources.nixpkgs-unstable}" { }; confPath = ./home.nix; }).activationPackage;


}
