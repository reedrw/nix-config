# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ../boot/efi.nix
    ../users/reed.nix
    ../optional/games
    ../optional/torrent.nix
    ../optional/btrfs-optin-persistence.nix
    ./hardware-configuration.nix
    ./persist.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ] ++ builtins.map (x: ../common + "/${x}") (builtins.attrNames (builtins.readDir ../common));

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

  # Remote decrypt via phone shortcut
  boot.initrd = {
    availableKernelModules = [ "alx" "r8169" ];
    network = {
      enable = lib.mkDefault true;
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjDgwhUiKpmpjx/yAz8SMC1bo7bS7LiZ+9LumJfHufv Shortcuts on iPhone 13 mini"
        ];
        # sudo ssh-keygen -t ed25519 -N "" -f /persist/secrets/initrd/ssh_host_ed25519_key
        # sudo ssh-keygen -t rsa -N "" -f /persist/secrets/initrd/ssh_host_rsa_key
        hostKeys = [ "/persist/secrets/initrd/ssh_host_rsa_key" "/persist/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };
  };

  specialisation = {
    "no-initrd-networking".configuration = {
      boot = {
        loader.grub.configurationName = "No initrd networking";
        initrd.network.enable = false;
      };
    };
  };

  # virtualisation.vmVariant = {
  #   boot = {
  #     initrd = {
  #       network.enable = false;
  #       postDeviceCommands = "";
  #     };
  #   };
  #   environment.persistence = {};
  #   home-manager.users.reed.home.persistence = {};
  #   environment.etc."crypttab".text = "";
  # };
  #
  networking.hostName = "nixos-desktop";
  networking.networkmanager.insertNameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  time.timeZone = "America/New_York";

  services.xserver = {
    videoDrivers = [ "amdgpu" ];
    monitorSection = ''
      Modeline "1920x1080_144.00"  452.50  1920 2088 2296 2672  1080 1083 1088 1177 -hsync +vsync
      Option "PreferredMode" "1920x1080_144.00"
    '';
    deviceSection = ''
      Option "SWCursor" "True"
    '';
  };

  services.autossh.sessions = [
    # {
    #   extraArguments = ''
    #     -o ServerAliveInterval=30 \
    #     -N -T -R 5000:localhost:22 142.4.208.215
    #   '';
    #   name = "ssh-port-forward";
    #   user = "reed";
    # }
    {
      extraArguments = ''
        -D 1337 -nNT localhost
      '';
      name = "ssh-socks-proxy";
      user = "reed";
    }
  ];

  services.jellyfin = {
    enable = true;
    user = "reed";
    group = "users";
    openFirewall = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        desiredgov = "performance";
        softrealtime = "on";
      };
    };
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

  programs = {
    droidcam.enable = true;
    nix-ld.enable = true;
    corectrl.enable = true;
  };

  system.stateVersion = "22.11";
}
