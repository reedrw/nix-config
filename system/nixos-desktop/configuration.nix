# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

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

  # services.foldingathome = {
  #   enable = true;
  #   user = "reed";
  #   extraArgs = [ "--power" "light" ];
  # };

  myUsers.reed.enable = true;

  custom = {
    persistDir = "/var/persist";
    prevDir = "/var/prev";
  };

  users = {
    mutableUsers = false;
    users.reed.hashedPasswordFile = "${config.custom.persistDir}/secrets/reed-passwordFile";
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
    enable = false;
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

  time.timeZone = "America/New_York";

  services.xserver.videoDrivers = [ "amdgpu" ];

  services.jellyfin = {
    enable = true;
    # remove this line when upgrading to 24.05
    package = pkgs.fromBranch.unstable.jellyfin;
    user = "reed";
    group = "users";
    openFirewall = true;
  };

  services.gnome.gnome-keyring.enable = true;

  nix.settings.cores = 8;

  programs.droidcam.enable = true;

  system.stateVersion = "22.11";
}
