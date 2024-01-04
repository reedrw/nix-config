# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, ... }:

{
  imports = [
    ./persist.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  custom.boot = {
    keyfile-unlock = {
      enable = true;
      default = true;
      device = "enc";
      keyFile = "/dev/disk/by-id/usb-SanDisk_Cruzer_Glide_4C530001240706109524-0:0-part2";
    };
    wipe.enable = true;
    efi.enable = true;
  };

  boot.initrd.services.lvm.enable = true;
  services.lvm.boot.thin.enable = true;

  users = {
    reed.enable = true;
    mutableUsers = false;
    users.reed.hashedPasswordFile = "/persist/secrets/reed-passwordFile";
  };

  custom.torrents = {
    enable = true;
    allowedUsers = [ "reed" ];
  };

  custom.steam = {
    enable = true;
    mullvad-exclude = true;
  };

  custom.aagl = {
    enable = true;
    mullvad-exclude = true;
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  custom.snapper = {
    enable = true;
    allowedUsers = [ "reed" ];
  };

  boot.loader.grub = {
    gfxmodeEfi = "1920x1080";
    gfxpayloadEfi = "keep";
  };

  networking.hostName = "nixos-desktop";

  time.timeZone = "America/New_York";

  services.xserver = {
    videoDrivers = [ "amdgpu" ];
    deviceSection = ''
      Option "SWCursor" "True"
    '';
  };

  services.jellyfin = {
    enable = true;
    user = "reed";
    group = "users";
    openFirewall = true;
  };

  services.gnome.gnome-keyring.enable = true;

  nix.settings.cores = 8;

  programs.droidcam.enable = true;

  system.stateVersion = "22.11";
}
