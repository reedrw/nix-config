{ ezModules, ... }:

{
  imports = [
    ../reed.nix
    ./xsession.nix
    ./syncthing.nix
    ./sway.nix
    ezModules.core
    ezModules.extra
    ezModules.filesharing
    ezModules.games
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];
}
