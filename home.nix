{ config, lib,  pkgs, ... }:

let
  # Base16 colorschemes
  # https://github.com/atpotts/base16-nix/blob/master/schemes.json
  scheme =  "onedark";
  variant = "onedark";

  sources = import ./nix-home/nix/sources.nix;

  base16-nix = builtins.fetchTarball {
    url = sources.base16-nix.url;
    sha256 = sources.base16-nix.sha256;
  };

in
{

  imports = [
    (import "${base16-nix}/base16.nix")
    ./nix-home/dunst.nix
    ./nix-home/nvim.nix
    ./nix-home/picom.nix
    ./nix-home/polybar.nix
    ./nix-home/ranger.nix
    ./nix-home/rofi.nix
    ./nix-home/urxvt.nix
    ./nix-home/xsession.nix
    ./nix-home/zsh.nix
  ];

  nixpkgs.overlays = [ (import ./nix-home/overlay.nix) ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "reed";
    homeDirectory = "/home/reed";
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  themes.base16 = {
    enable = true;
    scheme = "${scheme}";
    variant = "${variant}";
  };


  home.packages = with pkgs; [

    # home-manager
    (import sources.home-manager {inherit pkgs;}).home-manager

    # utilities
    c
    comma
    git
    niv

    # fonts
    artwiz-lemon
    dejavu_fonts
    noto-fonts
    scientifica
    twemoji-color-font

  ];

  services = {
    flameshot = {
      enable = true;
    };
  };

  home.stateVersion = "20.09";
}

