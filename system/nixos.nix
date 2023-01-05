# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ./boot/bios.nix
    ./users/reed.nix
  ] ++ builtins.map (x: ./common + "/${x}") (builtins.attrNames (builtins.readDir ./common));

  # Use the GRUB 2 boot loader.
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "nixos";
  time.timeZone = "America/New_York";

  system.stateVersion = "21.05";

}
