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
    kernelParams = [ "intel_pstate=active" ];
  };

  networking.hostName = "nixos-desktop";
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

  programs = {
    droidcam.enable = true;
    nix-ld.enable = true;
    steam.enable = true;
  };

  system.stateVersion = "20.03";

}
