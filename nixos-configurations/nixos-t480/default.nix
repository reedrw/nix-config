{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.graphical
    ezModules.networking
    ezModules'.extra.sshd
    ezModules'.users.reed
    ezModules'.virtualization.docker
    ./configuration.nix
  ];
}
