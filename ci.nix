let
  sources = import ./functions/sources.nix { sourcesFile = ./sources.json; };
  pkgs = import sources.nixpkgs { };

in
{

  nixos = (import "${sources.nixpkgs}/nixos" { configuration = import ./system/nixos/configuration.nix; }).system;
  nixos-t400 = (import "${sources.nixpkgs}/nixos" { configuration = import ./system/nixos-t400/configuration.nix; }).system;
  nixos-t520 = (import "${sources.nixpkgs}/nixos" { configuration = import ./system/nixos-t520/configuration.nix; }).system;
  nixos-desktop = (import "${sources.nixpkgs}/nixos" { configuration = import ./system/nixos-desktop/configuration.nix; }).system;
  home-manager = (import "${sources.home-manager}/home-manager/home-manager.nix" { confPath = ./home.nix; }).activationPackage;

}
