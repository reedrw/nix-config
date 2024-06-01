{ inputs, config, pkgs, ... }:

{

  imports = [
    "${inputs.nixos-hardware}/lenovo/thinkpad/t410"
  ];

  custom.boot.bios.enable = true;
  boot.loader.grub.device = "/dev/sda";

  common.bluetooth.enable = false;
  common.fonts.enable = false;
  common.logitech.enable = false;
  common.sound.enable = false;
  common.virtualization.enable = false;
  common.xserver.enable = false;

  programs.dconf.enable = true;

  hardware.trackpoint = {
    enable = true;
    emulateWheel = true;
  };

  services.mullvad-vpn.enable = false;
  services.logind.lidSwitch = "ignore";

  # Set your time zone.
  time.timeZone = "America/New_York";

  myUsers.reed.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?

}

