{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.graphical
    ezModules'.users.reed
    ezModules'.users.root
    ezModules'.networking.networking
    ./configuration.nix
  ];
}
