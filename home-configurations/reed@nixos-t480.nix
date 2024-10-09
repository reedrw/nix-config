{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules."reed@nixos-t480"
  ];
}
