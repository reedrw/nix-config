{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules."reed@nixos-desktop"
  ];
}
