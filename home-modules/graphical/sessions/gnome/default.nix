{ config, lib, pkgs, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: "${./.}/${x}");

  home.packages = with pkgs; [
    dconf-editor
  ];

  programs.gnome-shell.enable = true;

  systemd.user.services = with config.lib.functions; lib.mergeAttrsList [
    (mkSimpleService "xwayland-satellite" <| lib.getExe pkgs.xwayland-satellite)
  ];
}
