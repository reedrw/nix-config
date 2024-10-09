{ ezModules, ... }:
{
  imports = [
    ezModules.custom
    ezModules.common
    ezModules.myUsers
    ./configuration.nix
  ];
}
