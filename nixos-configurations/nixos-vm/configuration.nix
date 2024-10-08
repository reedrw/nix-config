# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  networking.hostName = "nixos-vm";
  myUsers.reed.enable = true;
  users.users.reed.password = "password";

  services.mullvad-vpn.enable = false;

  time.timeZone = "America/New_York";

  system.stateVersion = "22.11";
}
