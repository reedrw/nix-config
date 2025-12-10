{ config, ... }:

{
  services.flameshot.enable = true;

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    uiColor=#${config.lib.stylix.colors.base01}
  '';
}
