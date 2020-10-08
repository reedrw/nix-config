# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let

  # dummy hardware-configuration file for ci to work
  dummy-hw = builtins.toFile "dummy.nix" ''
  {
  fileSystems."/" =
    { device = "/dev/sda1";
      fsType = "ext4";
    };
  }
  '';

  # dummy file for ci to work
  dummy = builtins.toFile "dummy.nix" ''
  {

  }
  '';

  cachix = if builtins.pathExists ./cachix.nix
    then import ./cachix.nix else import dummy;

  hardware-configuration = if builtins.pathExists ./hardware-configuration.nix
    then import ./hardware-configuration.nix else import dummy-hw;

in
{
  imports =
    [
      # Use cachix
      cachix
      # Include the results of the hardware scan.
      hardware-configuration
      <nixos-hardware/lenovo/thinkpad/t420>
    ];

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    packageOverrides = pkgs: {
      nur = import <nur> {
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

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nixos-t520";
    networkmanager.enable = true;
  };

  sound.enable = true;

  hardware = {
    trackpoint = {
      enable = true;
      emulateWheel = true;
    };
    pulseaudio.enable = true;
  };

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
            name = "xsession";
            start = ''exec $HOME/.xsession'';
          }
        ];
      };
    };
  };

  fonts.fontconfig.enable = true;

  services.sshd.enable = true;

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

