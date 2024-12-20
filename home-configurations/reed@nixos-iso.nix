{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];
}
