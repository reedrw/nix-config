{ ezModules, ... }:
{
  imports = [
    ezModules.custom
    ezModules.common
    ezModules.myUsers
    ./nixos-desktop/configuration.nix
  ];
}
