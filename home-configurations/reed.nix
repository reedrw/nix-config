{ ezModules, ... }:

{
  imports = with ezModules; [
    comma
    default
    dunst
    easyeffects
    firefox
    functions
    games
    htop
    kitty
    lorri
    mpd
    mpv
    nixpkgs
    nvim
    obs-studio
    picom
    polybar
    ranger
    rofi
    shairport-sync
    social
    styling
    xsession
    zathura
    zsh
  ];
  home = {
    username = "reed";
    stateVersion = "20.09";
    homeDirectory = "/home/reed";
  };
}
