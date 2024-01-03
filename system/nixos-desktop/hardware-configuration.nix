# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" "dm-cache" "dm-cache-smq" "dm-cache-mq" "dm-cache-cleaner" ];
  boot.kernelModules = [ "kvm-amd"  "dm-cache" "dm-cache-smq" "dm-persistent-data" "dm-bio-prison" "dm-clone" "dm-crypt" "dm-writecache" "dm-mirror" "dm-snapshot" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/06911343-b3c6-4a86-b4ae-3fc23816a52a";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" ];
    };

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/0374e53d-6e1a-4788-96c9-c6059a295056";

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/06911343-b3c6-4a86-b4ae-3fc23816a52a";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/persist" =
    { device = "/dev/disk/by-uuid/06911343-b3c6-4a86-b4ae-3fc23816a52a";
      fsType = "btrfs";
      options = [ "subvol=persist" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/var/log" =
    { device = "/dev/disk/by-uuid/06911343-b3c6-4a86-b4ae-3fc23816a52a";
      fsType = "btrfs";
      options = [ "subvol=log" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/prev" =
    { device = "/dev/disk/by-uuid/06911343-b3c6-4a86-b4ae-3fc23816a52a";
      fsType = "btrfs";
      options = [ "subvol=prev" "compress=zstd" "noatime" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/C6CE-F98C";
      fsType = "vfat";
    };

  swapDevices =
    [
      # { device = "/dev/disk/by-uuid/f7aaaa3e-16ab-4981-a18f-d7e8181b6646"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.docker0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.tailscale0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wg-mullvad.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp14s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
