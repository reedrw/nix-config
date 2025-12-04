{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: ./${x});

  # remove ~/.config/mimeapps.list on activation
  xdg.configFile."mimeapps.list".force = true;
}
