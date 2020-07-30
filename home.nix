{ config, lib,  pkgs, ... }:

let
  # Base16 colorschemes
  # https://github.com/atpotts/base16-nix/blob/master/schemes.json
  scheme =  "onedark";
  variant = "onedark";

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
    { allowUnfree = true; }
  '';

  sources = import ./nix-home/nix/sources.nix;

  base16-nix = with sources.base16-nix;
  builtins.fetchTarball {
    url = url;
    sha256 = sha256;
  };

in
{

  imports = [
    "${base16-nix}/base16.nix"
    ./nix-home/dunst.nix
    ./nix-home/mpv.nix
    ./nix-home/nvim.nix
    ./nix-home/picom.nix
    ./nix-home/polybar.nix
    ./nix-home/ranger.nix
    ./nix-home/rofi.nix
    ./nix-home/urxvt.nix
    ./nix-home/xsession.nix
    ./nix-home/zsh.nix
  ];

  nixpkgs = {
    config = import "${config}";
    overlays = [ (import ./nix-home/overlay.nix) ];
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

  themes.base16 = {
    enable = true;
    scheme = "${scheme}";
    variant = "${variant}";
  };

  services = {
    flameshot = {
      enable = true;
    };
  };

  home.stateVersion = "20.09";
}

