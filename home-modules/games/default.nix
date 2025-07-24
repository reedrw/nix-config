{ pkgs, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: "${./.}/${x}");

  home.packages = [ pkgs.bottles ];
}
