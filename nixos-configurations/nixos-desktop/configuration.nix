{ inputs, config, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
    {
      services.jellyfin = {
        enable = true;
        user = "reed";
        group = "users";
        openFirewall = true;
      };

      custom.persistence.directories = [
        "/var/lib/jellyfin"
      ];
    }
    {
      services.thelounge.enable = true;

      custom.persistence.directories = [
        "/var/lib/thelounge"
      ];
    }
  ];

  networking.hostName = "nixos-desktop";
  nixpkgs.hostPlatform = "x86_64-linux";

  custom = {
    persistDir = "/var/persist";
    copyPersistPaths = true;
    prevDir = "/var/prev";
    boot = {
      keyfile-unlock = {
        enable = true;
        device = "enc";
        keyFile = "/dev/disk/by-id/usb-SanDisk_Cruzer_Glide_4C530001240706109524-0:0-part2";
      };
      wipe.enable = true;
      efi.enable = true;
    };
  };

  programs.persist-path-manager.enable = lib.mkForce false;

  services.lvm.boot.thin.enable = true;

  users = {
    mutableUsers = false;
    users.reed.hashedPasswordFile = "${config.custom.persistDir}/secrets/reed-passwordFile";
  };

  custom.steam = {
    enable = true;
    mullvad-exclude = true;
  };

  services.btrfs.autoScrub.enable = true;

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

  nix.settings.cores = 8;

  programs.droidcam.enable = true;

  system.stateVersion = "22.11";
}
