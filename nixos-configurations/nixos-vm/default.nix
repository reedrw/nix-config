{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.graphical
    ezModules'.users.reed
    ezModules'.networking.networking
    ./configuration.nix
  ];
}
