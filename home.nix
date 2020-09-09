{ config, lib,  pkgs, ... }:

let

  packages = with pkgs; [

    # utilities
    c
    comma
    git
    ix
    libreoffice
    nix-tree
    rsync

    # fonts
    artwiz-lemon
    scientifica

  ];

  sources = import ./nix/sources.nix;

  config = builtins.toFile "config.nix" ''
    {
      allowUnfree = true;
      packageOverrides = pkgs: {
        nur = import ${sources.NUR} {
          inherit pkgs;
        };
      };
    }
  '';

in
{

  imports = [
    ./modules/base16/default.nix
    ./modules/dunst/default.nix
    ./modules/mpd/default.nix
    ./modules/mpv/default.nix
    ./modules/nvim/default.nix
    ./modules/picom/default.nix
    ./modules/polybar/default.nix
    ./modules/ranger/default.nix
    ./modules/rofi/default.nix
    ./modules/urxvt/default.nix
    ./modules/weechat/default.nix
    ./modules/xsession/default.nix
    ./modules/zathura/default.nix
    ./modules/zsh/default.nix
  ];

  nixpkgs = {
    config = import "${config}";
    overlays = [ (import ./overlay.nix) ];
  };

  xdg = {
    userDirs = {
      enable = true;
      desktop = "\$HOME";
      documents = "\$HOME/files";
      download = "\$HOME/downloads";
      music = "\$HOME/music";
      pictures = "\$HOME/images";
      videos = "\$HOME/videos";
    };
    configFile = {
      "nixpkgs/config.nix".source = "${config}";
    };
  };

  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "reed";
    homeDirectory = "/home/reed";
    sessionVariables = {
      EDITOR = "nvim";
    };
    packages = packages;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}

