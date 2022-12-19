{ config, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  boot.loader.grub.theme = "${sources.distro-grub-themes}/customize/nixos";
}
