{ config, pkgs, ... }:
let
  gnomeEnabled = config.services.desktopManager.gnome.enable;
in
{
  # services.xserver.desktopManager.gnome.enable = true;
  #
  # programs.xwayland.enable = false;
  #
  # stylix.targets.gnome.enable = gnomeEnabled;
  #
  # environment.sessionVariables = {
  #   # ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  #   NIXOS_OZONE_WL = "1";
  # };
  #
  #
  # environment.systemPackages = with pkgs; [
  #   gnomeExtensions.forge
  # ];
}
