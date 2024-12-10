{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.core
    ezModules.extra
    ezModules.games
    ezModules.graphical
    ezModules.media
    ezModules.social
    ezModules."reed@nixos-desktop"
  ];
}
