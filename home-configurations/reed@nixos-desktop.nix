{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.common
    ezModules."reed@nixos-desktop"
  ];
}
