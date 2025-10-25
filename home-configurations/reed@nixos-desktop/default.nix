{ pkgs, ezModules, ... }:

{
  imports = [
    ../reed.nix
    ./qbittorrent.nix
    ./updog
    ./xsession
    ezModules.core
    ezModules.extra
    ezModules.games
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];

  home.packages = [
    (pkgs.jdownloader.override {
      darkTheme = true;
    })
  ];
}
