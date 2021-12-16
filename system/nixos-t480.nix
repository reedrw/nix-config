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
    "${sources.nixos-hardware}/lenovo/thinkpad/t480"
    "${sources.agenix}/modules/age.nix"
  ];
  # }}}
  # {{{ Nix and nixpkgs
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    packageOverrides = pkgs: {
      nur = import sources.NUR {
        inherit pkgs;
      };
    };
  };

  nix = {
    autoOptimiseStore = true;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    trustedUsers = [ "root" "@wheel" ];
  };
  # }}}
  # {{{ Boot settings
  # Use the systemd-boot EFI boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_lqx;
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
  hardware = {
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
    bluetooth.enable = true;
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    config.pipewire-pulse = builtins.fromJSON (builtins.readFile ./pipewire-pulse.conf.json);
    jack.enable = true;
  };

  # }}}
  # {{{ X server
  services.xserver = {
    enable = true;
    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
        accelSpeed = "10";
      };
    };
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
    autossh.sessions = [
      {
        extraArguments = ''
          -o ServerAliveInterval=30 \
          -N -T -R 5555:localhost:22 142.4.208.215
        '';
        name = "ssh-port-forward";
        user = "reed";
      }
    ];
    avahi = {
      enable = true;
      nssmdns = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };

    blueman.enable = true;

    mopidy = {
      enable = true;
      extensionPackages = with pkgs; [
        mopidy-mpd
        mopidy-spotify
      ];
      configuration = ''
        [core]
        restore_state = true

        [audio]
        output = pulsesink server=127.0.0.1:4713

        [mpd]
        enabled = true
      '';
      extraConfigFiles = [ config.age.secrets.spotify.path ];
    };

    openssh = {
      enable = true;
      passwordAuthentication = false;
      permitRootLogin = "no";
    };
  };
  # }}}
  # {{{ Networking
  networking = {
    networkmanager.enable = true;
    hostName = "nixos-t480";
    firewall.allowedUDPPortRanges = [ { from = 6001; to = 6101; } ];
    firewall.allowedTCPPorts = [ 5000 2049 ];
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
    dconf.enable = true;
    firejail.enable = true;
    gnupg.agent = {
      enable = true;
      pinentryFlavor = "tty";
    };
    noisetorch.enable = true;
  };
  environment = {
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      acpi
      solaar
      (import sources.agenix {}).agenix
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
      "video"
      "wheel"
    ];
    shell = pkgs.zsh;
  };
  # }}}
  # {{{ Secrets
  age.secrets = {
    spotify = {
      file = ./secrets/spotify.age;
      owner = "mopidy";
    };
  };
  # }}}
  # {{{
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
  # }}}

}
