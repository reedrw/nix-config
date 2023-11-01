# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, inputs, pkgs, ... }:
{
  imports = [
    ../boot/efi.nix
    ../users/reed.nix
    ../optional/btrfs-optin-persistence.nix
    ./hardware-configuration.nix
    ./persist.nix
    "${inputs.nixos-hardware}/lenovo/thinkpad/t480"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };

  powerManagement.resumeCommands = with pkgs; ''
    ${binPath xorg.xmodmap} -e 'keycode 117 = XF86Forward'
    ${binPath xorg.xmodmap} -e 'keycode 112 = XF86Back'
  '';

  networking.hostName = "nixos-t480";
  time.timeZone = "America/New_York";

  users.mutableUsers = false;
  users.users.reed.hashedPasswordFile = "/persist/secrets/reed-passwordFile";

  hardware = {
    opengl = {
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
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

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  programs.persist-path-manager = {
    enable = true;
    config = {
      activateCommand = "ldp";
      persistJson = "/home/reed/.config/nixpkgs/system/nixos-t480/persist.json";
      persistDir = "/persist";
      snapper = {
        enable = true;
        config = "persist";
      };
    };
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


  services.xserver = {
    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
        accelSpeed = "10";
      };
    };
    displayManager.sessionCommands = ''
      xinput set-prop "TPPS/2 IBM TrackPoint" "libinput Accel Speed" 1
    '';
  };

  programs = {
    droidcam.enable = true;
    steam.enable = true;
  };

  environment.systemPackages = with pkgs; [ acpi ];

  system.stateVersion = "21.05";
}
