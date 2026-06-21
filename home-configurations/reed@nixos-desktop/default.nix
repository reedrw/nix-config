{ ezModules, ... }:

{
  imports = [
    ../reed.nix
    ./syncthing.nix
    ./firefox.nix
    ./kitty.nix
    ./mpv
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
