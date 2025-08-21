{ pkgs, lib, osConfig, ... }:
let
  gnomeEnabled = osConfig.services.xserver.desktopManager.gnome.enable;

  extensions = lib.optionals gnomeEnabled ((with pkgs.gnomeExtensions; [
    caffeine
    forge
    rounded-window-corners-reborn
    # removable-drive-menu
    # window-is-ready-remover
  ]) ++ [
    pkgs.pinned.gnomeExtensions.v426325.another-window-session-manager
  ]);
in
{
  home.packages = extensions;
  programs.gnome-shell.extensions = extensions |> map (package: {
    inherit package;
  });
  # home.packages = extensions;
  # dconf.settings = {
  #   "org/gnome/shell" = {
  #     enabledExtensions = extensions |> map (ext: ext.extensionUuid);
  #   };
  # };
}
