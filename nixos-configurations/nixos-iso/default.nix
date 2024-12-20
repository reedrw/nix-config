{ inputs, ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.graphical
    ezModules'.users.reed
    ezModules'.networking.bluetooth
    ezModules'.networking.networking
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-base.nix"
    ({lib, pkgs, ...}: {
      boot.plymouth.enable = lib.mkForce false;
      boot.initrd.systemd.enable = lib.mkForce false;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      environment.systemPackages = with pkgs; [
        arandr
      ];
    })
    ./configuration.nix
  ];
}
