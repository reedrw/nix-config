{ pkgs, config, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: "${./.}/${x}");

  # remove ~/.config/mimeapps.list on activation
  home.activation = let
    removeMineapps = pkgs.writeShellScript "removeMineapps" ''
      mimeapps="$HOME/.config/mimeapps.list"
      if [ -f "$mimeapps" ]; then
        rm "$mimeapps"
      fi
    '';
  in {
    removeMineapps = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
      run ${removeMineapps}
    '';
  };
}
