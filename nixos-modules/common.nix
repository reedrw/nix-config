{ lib, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x [ "common.nix" "custom" ])
    |> builtins.attrNames
    |> builtins.filter (x: !lib.hasPrefix "user-" x)
    |> map (x: "${./.}/${x}");
}
