{ config, pkgs, ... }:

{
  hardware.firmware = with pkgs; [ linux-firmware ];

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
}
