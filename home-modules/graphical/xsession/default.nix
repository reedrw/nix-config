{ osConfig, ... }:

{
  imports = if osConfig.services.xserver.desktopManager.gnome.enable then
    [ ./gnome ]
  else
    [ ./i3 ];
}
