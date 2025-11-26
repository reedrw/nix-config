{ config, osConfig, lib, pkgs, ... }:
let
  gnomeEnabled = osConfig.services.desktopManager.gnome.enable;
in
{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: ./${x});

  home.packages = lib.optionals gnomeEnabled (with pkgs; [
    dconf-editor
  ]);

  programs.gnome-shell.enable = gnomeEnabled;

  systemd.user.services = lib.optionalAttrs gnomeEnabled (with config.lib.functions; lib.mergeAttrsList [
    (mkSimpleService "xwayland-satellite" <| lib.getExe pkgs.xwayland-satellite)
  ]);
}
