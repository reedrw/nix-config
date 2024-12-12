{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.extra
    ezModules.graphical
    ezModules.networking
    ezModules'.virtualization.docker
    ezModules'.users.reed
    ./configuration.nix
  ];
}
