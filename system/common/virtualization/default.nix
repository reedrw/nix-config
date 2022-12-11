{ config, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  boot.kernelModules = [ "kvm-intel" ];
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    (versionConditionalOverride "1.4.1" distrobox
      (distrobox.overrideAttrs (
        old: rec {
          version = shortenRev sources.distrobox.rev;
          src = sources.distrobox;
        }
      ))
    )
  ];
}
