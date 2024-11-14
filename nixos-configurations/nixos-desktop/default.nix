{ ezModules, ... }:
{
  imports = [
    ezModules.custom
    ezModules.common
    ezModules.user-reed
    ezModules.user-spicypillow
    ./configuration.nix
  ];
}
