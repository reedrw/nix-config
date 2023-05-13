# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:

{
  imports = [
    ./boot/efi.nix
    ./users/reed.nix
    ./optional/games
    ./optional/torrent.nix
    ./hardware/desktop.nix
    "${inputs.nixos-hardware}/common/cpu/intel"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ] ++ builtins.map (x: ./common + "/${x}") (builtins.attrNames (builtins.readDir ./common));

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "ip=dhcp" "intel_pstate=active" ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };

  boot.loader.grub = {
    gfxmodeEfi = "1920x1080";
    gfxpayloadEfi = "keep";
  };

  # Remote decrypt via phone shortcut
  boot.initrd = {
    availableKernelModules = [ "alx" ];
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjDgwhUiKpmpjx/yAz8SMC1bo7bS7LiZ+9LumJfHufv Shortcuts on iPhone 13 mini"
        ];
        # sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key
        # sudo ssh-keygen -t rsa -N "" -f /etc/secrets/initrd/ssh_host_rsa_key
        hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };
  };

  networking.hostName = "nixos-desktop";
  networking.networkmanager.insertNameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  time.timeZone = "America/New_York";

  services.xserver = {
    videoDrivers = [ "amdgpu" ];
    monitorSection = ''
      ModeLine "1920x1080_144.00"  325.08  1920 1944 1976 2056  1080 1083 1088 1098 +hsync +vsync
      Option "PreferredMode" "1920x1080_144.00"
    '';
  };

  services.autossh.sessions = [
    {
      extraArguments = ''
        -o ServerAliveInterval=30 \
        -N -T -R 5000:localhost:22 142.4.208.215
      '';
      name = "ssh-port-forward";
      user = "reed";
    }
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
    BigHD /dev/disk/by-uuid/c5d3a438-5719-4020-be28-f258a15c5ab7 /etc/secrets/crypt/BigHD.key luks
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

  programs = {
    droidcam.enable = true;
    nix-ld.enable = true;
    steam.enable = true;
  };

  system.stateVersion = "22.05";
}
