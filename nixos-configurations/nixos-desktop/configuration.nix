{ pkgs-unstable, inputs, config, ... }:

{
  imports = [
    ./persist.nix
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  networking.hostName = "nixos-desktop";
  nixpkgs.hostPlatform = "x86_64-linux";

  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama;
    acceleration = "rocm";
    openFirewall = true;
  };

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

  custom = {
    persistDir = "/var/persist";
    prevDir = "/var/prev";
  };

  custom.nix-ssh-serve = {
    enable = true;
    keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4QB7g+vkkytelSG2Wcibmxn7b3ZhnezFjpppD/MCWW root@nixos-t480"
    ];
    secretKeyFiles = [
      "${config.custom.persistDir}/secrets/nix-store/nix-store-secret-key.pem"
    ];
  };

  users = {
    mutableUsers = false;
    users.reed.hashedPasswordFile = "${config.custom.persistDir}/secrets/reed-passwordFile";
  };

  custom.steam = {
    enable = true;
    mullvad-exclude = false;
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

  networking.firewall = {
    # 5900 : VNC
    allowedTCPPorts = [ 5900 ];
    allowedUDPPorts = [ 5900 ];
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
