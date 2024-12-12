{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.extra
    ezModules.graphical
    ezModules.networking
    ezModules.virtualization
    ezModules'.users.reed
    ./configuration.nix
  ];
}
