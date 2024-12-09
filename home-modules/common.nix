{ lib, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x [ "common.nix" ])
    |> builtins.attrNames
    |> builtins.filter (x: !lib.hasInfix "@" x)
    |> map (x: "${./.}/${x}");
}
