{ ezModules, ezModules', ... }:

{
  imports = [
    ../reed.nix
    ./kitty.nix
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
    ezModules'.games.minecraft
    ezModules'.games.steam
  ];
}
