{ ezModules, ... }:
{
  imports = [
    ezModules.custom

    ezModules.gnupg
    ezModules.kernel
    ezModules.networking
    ezModules.nixpkgs
    ezModules.opengl
    ezModules.sshd
    ezModules.styling
    ezModules.tweaks
    ezModules.zsh

    ezModules.user-reed

    ./configuration.nix
  ];
}
