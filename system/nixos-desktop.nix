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

  # {{{ Imports
  imports = [
    # Use cachix
    cachix
    # Include the results of the hardware scan.
    hardware-configuration
    "${sources.nixos-hardware}/common/cpu/intel"
    "${sources.nixos-hardware}/common/pc/ssd"
  ];
  # }}}
  # {{{ Nix and nixpkgs
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
    package = pkgs.nixUnstable.overrideAttrs (
      old: {
        src = sources.nix;
      }
    );
    autoOptimiseStore = true;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    trustedUsers = [ "root" "@wheel" ];
  };
  # }}}
  # {{{ Boot settings
  # Use the systemd-boot EFI boot loader.
  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelPackages = pkgs.linuxPackages_lqx;
    kernelParams = [ "intel_pstate=active" ];
    supportedFilesystems = [ "ntfs" ];
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
        set-default-sink alsa_output.usb-Schiit_Audio_Schiit_Modi_3_-00.analog-stereo
      '';
    };
    logitech = {
      wireless = {
        enable = true;
        enableGraphical = true;
      };
    };
    opengl = {
      enable = true;
      driSupport = true;
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
      noto-fonts-emoji
      open-sans
      source-code-pro
      ttf_bitstream_vera
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
  services = {
    avahi = {
      enable = true;
      nssmdns = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };

    nfs.server = {
      enable = true;
      exports = ''
        /export       192.168.1.0/24(insecure,rw,sync,no_subtree_check)
        /export/BigHD 192.168.1.0/24(insecure,rw,sync,no_subtree_check)
      '';
    };

    plex = {
      enable = true;
      openFirewall = true;
    };

    sshd.enable = true;
  };
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
  programs = {
    adb.enable = true;
    gnupg.agent = {
      enable = true;
      pinentryFlavor = "tty";
    };
  };
  environment = {
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      solaar
    ];
  };
  # }}}
  # {{{ Users
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [
      "adbusers"
      "audio"
      "docker"
      "libvirtd"
      "networkmanager"
      "wheel"
    ];
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
