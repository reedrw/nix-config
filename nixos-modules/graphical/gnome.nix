{ config, pkgs, ... }:
let
  gnomeEnabled = config.services.xserver.desktopManager.gnome.enable;
in
{
  services.xserver.desktopManager.gnome.enable = false;

  programs.xwayland.enable = gnomeEnabled;

  stylix.targets.gnome.enable = gnomeEnabled;

  environment.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  environment.systemPackages = with pkgs; [
    gnomeExtensions.forge
  ];
}
