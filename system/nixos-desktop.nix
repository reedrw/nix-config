# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  sources = import ../nix/sources.nix { sourcesFile = ../nix/sources.json; };
in
{
  imports = [
    ./boot/efi.nix
    ./users/reed.nix
    "${sources.nixos-hardware}/common/cpu/intel"
    "${sources.nixos-hardware}/common/pc/ssd"
  ] ++ builtins.map (x: ./common + ("/"  + x)) (builtins.attrNames (builtins.readDir ./common));

  boot = {
    kernelPackages = pkgs.linuxPackages_lqx;
    kernelPatches = [{
      name = "muqss-scheduler";
      patch = null;
      extraConfig = ''
        SCHED_MUQSS y
        RQ_SMT y
      '';
    }];
    kernelParams = [ "ip=dhcp" "intel_pstate=active" ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
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
        hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };
  };

  # programs.ssh.extraConfig = ''
  #   Host eu.nixbuild.net
  #     PubkeyAcceptedKeyTypes ssh-ed25519
  #     IdentityFile /home/reed/.ssh/my-nixbuild-key
  # '';
  #
  # programs.ssh.knownHosts = {
  #   nixbuild = {
  #     hostNames = [ "eu.nixbuild.net" ];
  #     publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
  #   };
  # };
  #
  # nix = {
  #   distributedBuilds = true;
  #   buildMachines = [
  #     {
  #       hostName = "eu.nixbuild.net";
  #       system = "x86_64-linux";
  #       maxJobs = 100;
  #       supportedFeatures = [ "benchmark" "big-parallel" ];
  #     }
  #   ];
  # };

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

  services.autossh.sessions = [{
    extraArguments = ''
      -o ServerAliveInterval=30 \
      -N -T -R 5000:localhost:22 142.4.208.215
    '';
    name = "ssh-port-forward";
    user = "reed";
  }];

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        desiredgov = "performance";
        softrealtime = "on";
      };
    };
  };

  services.gnome.gnome-keyring.enable = true;

  programs = {
    droidcam.enable = true;
    nix-ld.enable = true;
    steam.enable = true;
  };

  system.stateVersion = "20.03";
}
