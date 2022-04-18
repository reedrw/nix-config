{ config, pkgs, ... }:

{
  boot.kernelModules = [ "kvm-intel" ];
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };
}
