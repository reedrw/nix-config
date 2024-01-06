# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ ... }:

{
  users.reed.enable = true;
  users.users.reed.password = "password";

  services.mullvad-vpn.enable = false;

  networking.hostName = "nixos-vm";
  time.timeZone = "America/New_York";

  system.stateVersion = "22.11";
}
