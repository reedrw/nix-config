{ inputs, ezModules, ezModules', ... }:
{
  imports = [
    ezModules.core
    ezModules.custom
    ezModules.graphical
    ezModules'.users.reed
    ezModules'.networking.bluetooth
    ezModules'.networking.networking
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-base.nix"
    ./configuration.nix
  ];
}
