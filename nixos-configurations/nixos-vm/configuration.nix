{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "nixos-vm";
  time.timeZone = "America/New_York";

  custom = {
    vmStaging.enable = true;
  };

  system.stateVersion = "22.11";
}
