{ ezModules, ... }:
{
  imports = [
    ezModules.custom
    ezModules.common
    ezModules.user-reed
    ./configuration.nix
  ];
}
