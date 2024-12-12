{ ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.networking
    ezModules'.extra.sshd
    ezModules'.users.reed
    ./configuration.nix
  ];
}
