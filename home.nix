{ config, lib,  pkgs, ... }:

let

  packages = with pkgs; [

    # utilities
    cachix
    firefox
    git
    libreoffice
    nix-tree
    nur.repos.reedrw.comma
    nur.repos.reedrw.ix

    # fonts
    nur.repos.reedrw.artwiz-lemon
    nur.repos.reedrw.scientifica

  ];

  sources = import ./nix/sources.nix;

  config = builtins.toFile "config.nix" ''
    {
      allowUnfree = true;
      allowBroken = true;
      packageOverrides = pkgs: {
        nur = import ${sources.NUR} {
          inherit pkgs;
        };
      };
    }
  '';

  user = builtins.getEnv "USER";

in
{

  imports = [
    ./modules/base16
    ./modules/dunst
    ./modules/mpd
    ./modules/mpv
    ./modules/nvim
    ./modules/picom
    ./modules/polybar
    ./modules/ranger
    ./modules/rofi
    ./modules/styling
    ./modules/urxvt
    ./modules/weechat
    ./modules/xsession
    ./modules/zathura
    ./modules/zsh
  ];

  nixpkgs = {
    config = import "${config}";
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
    username = user;
    homeDirectory = "/home/" + user;
    sessionVariables = {
      EDITOR = "nvim";
    };
    packages = packages;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}

