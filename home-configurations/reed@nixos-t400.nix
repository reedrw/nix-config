{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.core
    ezModules.extra
  ];
}
