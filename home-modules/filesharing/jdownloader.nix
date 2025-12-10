{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    (mullvadExclude <| jdownloader.override {
      darkTheme = config.stylix.polarity == "dark";
      extraOptions = {
        "org.jdownloader.extensions.extraction.ExtractionExtension" = {
          deletearchivefilesafterextractionaction = "NULL";
        };
        "org.jdownloader.settings.GeneralSettings" = {
          maxsimultanedownloads = 5;
          defaultdownloadfolder = "${config.xdg.dataHome}/jdownloader/downloads";
        };
        "org.jdownloader.settings.GraphicalUserInterfaceSettings" = lib.optionalAttrs (config.stylix.polarity == "light")
        {
          lookandfeeltheme = "FLATLAF_LIGHT";
        };
      };
    })
  ];
}
