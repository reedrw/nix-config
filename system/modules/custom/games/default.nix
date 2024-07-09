{ inputs, ... }:

{
  imports = [
    inputs.aagl.nixosModules.default
    ./aagl
    ./hrl
    ./zzz
  ];
}
