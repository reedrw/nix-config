# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, pkgs, config, ... }:
{
  imports = [
    ./persist.nix
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/lenovo/thinkpad/t480"
  ];

  networking.hostName = "nixos-t480";

  time.timeZone = "America/New_York";

  users = {
    mutableUsers = false;
    users.reed.hashedPasswordFile = "${config.custom.persistDir}/secrets/reed-passwordFile";
  };

  hardware = {
    graphics = {
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    trackpoint = {
      enable = true;
      sensitivity = 255;
      speed = 255;
    };
    acpilight.enable = true;
  };

  services.btrfs.autoScrub.enable = true;

  custom = {
    persistDir = "/var/persist";
    prevDir = "/var/prev";
  };

  custom.boot = {
    keyfile-unlock = {
      enable = true;
      default = false;
      device = "enc";
      keyFile = "/dev/disk/by-id/usb-SanDisk_Cruzer_Glide_4C530001240706109524-0:0-part2";
    };
    wipe.enable = true;
    efi.enable = true;
  };

  custom.snapper = {
    enable = true;
    allowedUsers = [ "reed" ];
  };

  services.libinput = {
    enable = true;
    mouse = {
      accelProfile = "flat";
      accelSpeed = "10";
    };
  };

  services.xserver.displayManager.sessionCommands = ''
    xinput set-prop "TPPS/2 IBM TrackPoint" "libinput Accel Speed" 1
  '';

  programs.droidcam.enable = true;

  environment.systemPackages = with pkgs; [ acpi ];

  system.stateVersion = "21.05";
}
