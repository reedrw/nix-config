{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: ./${x});

  services.mpris-proxy.enable = true;
}
