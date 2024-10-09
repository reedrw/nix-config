{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.common
    ezModules."reed@nixos-t480"
  ];
}
