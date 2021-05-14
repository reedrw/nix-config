# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).


{ config, pkgs, ... }:
let
  sources = import ../../functions/sources.nix { sourcesFile = ../../sources.json; };
  # dummy files for ci to work
  dummy = builtins.toFile "dummy.nix" "{}";
  dummy-hw = builtins.toFile "dummy.nix" ''
    {
      fileSystems."/".device = "/dev/sda1";
      fileSystems."/".fsType = "ext4";
    }
  '';

  cachix =
    if builtins.pathExists ./cachix.nix
    then import ./cachix.nix else import dummy;

  hardware-configuration =
    if builtins.pathExists ./hardware-configuration.nix
    then import ./hardware-configuration.nix else import dummy-hw;

in
{
  imports = [
    # Use cachix
    cachix
    # Include the results of the hardware scan.
    hardware-configuration
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    packageOverrides = pkgs: {
      nur = import sources.nur {
        inherit pkgs;
      };
    };
  };

  nix = {
    autoOptimiseStore = true;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  networking = {
    hostName = "nixos-t400"; # Define your hostname.
    networkmanager.enable = true;
  };

  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/sda";
  };

  # Enable sound.
  sound.enable = true;

  hardware = {
    trackpoint = {
      enable = true;
      emulateWheel = true;
    };
    pulseaudio.enable = true;
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  services = {
    xserver = {
      enable = true;
      displayManager = {
        autoLogin = {
          enable = true;
          user = "reed";
        };
        lightdm = {
          enable = true;
          greeter.enable = false;
        };
        session = [
          {
            manage = "desktop";
            name = "home-manager";
            start = ''exec $HOME/.xsession'';
          }
        ];
      };
    };
  };

  fonts.fontconfig.enable = true;

  users.users.reed = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" ];
    shell = pkgs.zsh;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?

}
