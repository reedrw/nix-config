# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, pkgs, ... }:
{
  imports = [
    ../users/reed.nix
    ./hardware-configuration.nix
    ./persist.nix
    "${inputs.nixos-hardware}/lenovo/thinkpad/t480"
  ];

  networking.hostName = "nixos-t480";
  time.timeZone = "America/New_York";

  users.mutableUsers = false;
  users.users.reed.hashedPasswordFile = "/persist/secrets/reed-passwordFile";

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

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  custom.boot = {
    wipe.enable = true;
    efi.enable = true;
  };

  custom.snapper = {
    enable = true;
    allowedUsers = [ "reed" ];
  };

  services.xserver = {
    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
        accelSpeed = "10";
      };
    };
    displayManager.sessionCommands = ''
      xinput set-prop "TPPS/2 IBM TrackPoint" "libinput Accel Speed" 1
    '';
  };

  programs.droidcam.enable = true;

  environment.systemPackages = with pkgs; [ acpi ];

  system.stateVersion = "21.05";
}
