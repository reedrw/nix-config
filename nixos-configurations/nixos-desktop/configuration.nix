{ inputs, config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  networking.hostName = "nixos-desktop";
  nixpkgs.hostPlatform = "x86_64-linux";

  custom = {
    persistDir = "/var/persist";
    persistJSON = ./persist.json;
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

  powerManagement.cpuFreqGovernor = "ondemand";

  services.udev.extraRules = ''
    # HDD
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

    # SSD
    ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

    # NVMe SSD
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
  '';

  services.thelounge.enable = true;

  boot.initrd.services.lvm.enable = true;

  boot.kernelParams = [
    "pcie_aspm=off"
  ];

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

  services.jellyfin = {
    enable = true;
    user = "reed";
    group = "users";
    openFirewall = true;
  };

  nix.settings.cores = 8;

  programs.droidcam.enable = true;

  system.stateVersion = "22.11";
}
