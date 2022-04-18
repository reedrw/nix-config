# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  sources = import ../nix/sources.nix { sourcesFile = ../nix/sources.json; };
  # {{{ Import cachix and hardware-configuration if they exist (for Github Actions)
  # dummy files for ci to work
  dummy = builtins.toFile "dummy.nix" "{}";
  dummy-hw = builtins.toFile "dummy.nix" ''
    {
      fileSystems."/".device = "/dev/sda1";
      fileSystems."/".fsType = "ext4";
    }
  '';

  cachix =
    if builtins.pathExists /etc/nixos/cachix.nix
    then import /etc/nixos/cachix.nix else import dummy;

  hardware-configuration =
    if builtins.pathExists /etc/nixos/hardware-configuration.nix
    then import /etc/nixos/hardware-configuration.nix else import dummy-hw;
  # }}}

in
{

  imports = [
    ./boot/efi.nix
    ./users/reed.nix
    "${sources.nixos-hardware}/lenovo/thinkpad/t480"
  ] ++ builtins.map (x: ./common + ("/"  + x)) (builtins.attrNames (builtins.readDir ./common));

  boot.kernelPackages = pkgs.linuxPackages_lqx;

  networking.hostName = "nixos-t480";
  time.timeZone = "America/New_York";

  hardware = {
    opengl = {
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    trackpoint = {
      enable = true;
      sensitivity = 255;
      speed = 255;
    };
    acpilight.enable = true;
  };

  services.xserver = {
    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
        accelSpeed = "10";
      };
    };
  };

  services.autossh.sessions = [{
    extraArguments = ''
      -o ServerAliveInterval=30 \
      -N -T -R 5555:localhost:22 142.4.208.215
    '';
    name = "ssh-port-forward";
    user = "reed";
  }];

  programs.droidcam.enable = true;

  environment.systemPackages = with pkgs; [ acpi ];

  system.stateVersion = "21.05";
}
