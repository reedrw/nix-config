{ ezModules, ... }:

{
  imports = [
    ../reed.nix
    ./firefox.nix
    ./kitty.nix
    ./mpv
    ./sway.nix
    ./syncthing.nix
    ezModules.core
    ezModules.extra
    ezModules.filesharing
    ezModules.games
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];
}
