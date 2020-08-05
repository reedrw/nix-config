{ config, lib,  pkgs, ... }:

let

  packages = with pkgs; [

    # utilities
    c
    comma
    git
    ix
    nix-tree

    # fonts
    artwiz-lemon
    dejavu_fonts
    noto-fonts
    scientifica
    twemoji-color-font

  ];

  config = builtins.toFile "config.nix" ''
    {
      allowUnfree = true;
      packageOverrides = pkgs: {
        nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
          inherit pkgs;
        };
      };
    }
  '';

in
{

  imports = [
    ./nix-home/base16/default.nix
    ./nix-home/dunst/default.nix
    ./nix-home/mpv/default.nix
    ./nix-home/nvim/default.nix
    ./nix-home/picom/default.nix
    ./nix-home/polybar/default.nix
    ./nix-home/ranger/default.nix
    ./nix-home/rofi/default.nix
    ./nix-home/st/default.nix
    ./nix-home/xsession/default.nix
    ./nix-home/zsh/default.nix
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

  programs = {
    home-manager = {
      enable = true;
    };
  };

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

  home.stateVersion = "20.09";
}

