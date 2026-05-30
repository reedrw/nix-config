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
    ezModules'.users.root
    ./configuration.nix
  ];
}
