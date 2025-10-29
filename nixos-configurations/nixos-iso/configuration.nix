{ pkgs, lib, ... }:

{

  boot = {
    plymouth.enable = lib.mkForce false;
    initrd.systemd.enable = lib.mkForce false;
    kernelPackages = lib.mkForce pkgs.linuxPackages;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "nixos-iso";

  users.users.nixos.shell = pkgs.zsh;

  time.timeZone = "America/New_York";

  system.stateVersion = lib.trivial.release;
}
