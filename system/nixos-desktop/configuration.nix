# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
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
    if builtins.pathExists ./cachix.nix
    then import ./cachix.nix else import dummy;

  hardware-configuration =
    if builtins.pathExists ./hardware-configuration.nix
    then import ./hardware-configuration.nix else import dummy-hw;
  # }}}
in
{

  # {{{ Imports
  imports = [
    # Use cachix
    cachix
    # Include the results of the hardware scan.
    hardware-configuration
    <nixos-hardware/common/cpu/intel>
    <nixos-hardware/common/pc/ssd>
  ];
  # }}}
  # {{{ Nix and nixpkgs
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
  # }}}
  # {{{ Boot settings
  # Use the systemd-boot EFI boot loader.
  boot = {
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "ntfs" ];
    extraModulePackages = [ pkgs.nur.repos.suhr.v4l2loopback-dc ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
  # }}}
  # {{{ Time and locale
  time.timeZone = "America/New_York";
  # }}}
  # {{{ Sound and hardware
  sound.enable = true;

  hardware = {
    pulseaudio = {
      enable = true;
      support32Bit = true;
      extraConfig = ''
        set-default-sink alsa_output.pci-0000_00_1b.0.analog-stereo
      '';
    };
    opengl = {
      enable = true;
      driSupport32Bit = true;
      extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    };
  };
  # }}}
  # {{{ X server
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
    monitorSection = ''
      ModeLine "1920x1080_144.00"  325.08  1920 1944 1976 2056  1080 1083 1088 1098 +hsync +vsync
      Option "PreferredMode" "1920x1080_144.00"
    '';
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
  # }}}
  # {{{ Fonts
  fonts = {
    fonts = with pkgs; [
      carlito
      corefonts
      dejavu_fonts
      ipafont
      kochi-substitute
      source-code-pro
      ttf_bitstream_vera
      noto-fonts-emoji
    ];
    enableDefaultFonts = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "Bitstream Vera Sans Mono"
          "DejaVu Sans Mono"
          "IPAGothic"
        ];
        sansSerif = [
          "Bitstream Vera Sans"
          "DejaVu Sans Serif"
          "IPAPGothic"
        ];
        serif = [
          "Bitstream Vera Serif"
          "DejaVu Serif"
          "IPAPMincho"
        ];
      };
    };
  };
  # }}}
  # {{{ Services
  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export       192.168.1.0/24(insecure,rw,sync,no_subtree_check)
      /export/BigHD 192.168.1.0/24(insecure,rw,sync,no_subtree_check)
    '';
  };

  services.plex.enable = true;

  services.sshd.enable = true;
  # }}}
  # {{{ Networking
  networking = {
    networkmanager.enable = true;
    hostName = "nixos-desktop";
    firewall.allowedTCPPorts = [ 2049 ];
    firewall.allowedUDPPorts = [ 5353 ];
  };
  # }}}
  # {{{ Virtualization
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };
  # }}}
  # {{{ Programs
  programs.adb.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];
  # }}}
  # {{{ Users
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [ "adbusers" "audio" "docker" "libvirtd" "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
  # }}}
  # {{{
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?
  # }}}

}
