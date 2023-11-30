# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ../users/reed.nix
    ./hardware-configuration.nix
    ./persist.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "ip=dhcp" ];
    kernelModules = [
      # Nuvoton nct6687 needs this driver
      "nct6683"
    ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "usbcore.old_scheme_first" = 1;
    };
    extraModprobeConfig = ''
      options nct6683 force=1
      options kvm_amd avic=1
    '';
  };

  custom.boot = {
    remote-unlock = {
      enable = true;
      default = false;
    };
    wipe.enable = true;
    efi.enable = true;
  };

  hardware.firmware = with pkgs; [ linux-firmware ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  services.snapper = {
    configs.persist = {
      SUBVOLUME = "/persist";
      ALLOW_USERS = [ "reed" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 168;
      TIMELINE_LIMIT_DAILY = 365;
      TIMELINE_LIMIT_WEEKLY = 100;
      TIMELINE_LIMIT_MONTHLY = 36;
      TIMELINE_LIMIT_YEARLY = 0;
    };
  };

  boot.loader.grub = {
    gfxmodeEfi = "1920x1080";
    gfxpayloadEfi = "keep";
  };

  users.mutableUsers = false;
  users.users.reed.hashedPasswordFile = "/persist/secrets/reed-passwordFile";

  networking.hostName = "nixos-desktop";

  time.timeZone = "America/New_York";

  services.xserver = {
    videoDrivers = [ "amdgpu" ];
    deviceSection = ''
      Option "SWCursor" "True"
    '';
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


  services.jellyfin = {
    enable = true;
    user = "reed";
    group = "users";
    openFirewall = true;
  };

  environment.etc."crypttab".text = ''
    BigHD /dev/disk/by-uuid/c5d3a438-5719-4020-be28-f258a15c5ab7 /persist/secrets/crypt/BigHD.key luks
  '';

  fileSystems = {
    "/mnt/BigHD" = {
      fsType = "ext4";
      device = "/dev/mapper/BigHD";
      options = [
        "nofail"
      ];
    };
    "/var/lib/deluge/Downloads" = {
      device = "/mnt/BigHD/torrents";
      options = [ "bind" ];
    };
  };

  services.gnome.gnome-keyring.enable = true;

  nix.settings.cores = 8;

  programs.droidcam.enable = true;

  system.stateVersion = "22.11";
}
