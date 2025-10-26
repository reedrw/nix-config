{ ezModules, ... }:

{
  imports = [
    ../reed.nix
    ./xsession
    ezModules.core
    ezModules.extra
    ezModules.filesharing
    ezModules.games
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];
}
