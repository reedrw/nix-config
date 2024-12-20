# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  # imports = [
  #   ./hardware-configuration.nix
  # ];

  networking.hostName = "nixos-iso";
  users.users.reed.password = "password";

  time.timeZone = "America/New_York";

  system.stateVersion = "22.11";
}
