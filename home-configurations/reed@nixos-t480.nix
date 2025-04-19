{ ezModules, ezModules', ... }:

{
  imports = [
    ./reed.nix
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
    ezModules'.games.minecraft
    ezModules'.games.steam
    ezModules."reed@nixos-t480"
  ];
}
