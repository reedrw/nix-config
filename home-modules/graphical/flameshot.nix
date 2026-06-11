{ config, ... }:

{
  services.flameshot = {
    enable = true;
    settings.General = {
      uiColor = "#${config.lib.stylix.colors.base01}";
      useGrimAdapter = true;
      disabledGrimWarning = true;
      showStartupLaunchMessage = false;
    };
  };
}
