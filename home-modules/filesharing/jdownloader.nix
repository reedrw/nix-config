{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    (mullvadExclude <| jdownloader.override {
      darkTheme = true;
      extraOptions = {
        "org.jdownloader.extensions.extraction.ExtractionExtension" = {
          deletearchivefilesafterextractionaction = "NULL";
        };
        "org.jdownloader.settings.GeneralSettings" = {
          maxsimultanedownloads = 5;
          defaultdownloadfolder = "${config.xdg.dataHome}/jdownloader/downloads";
        };
      };
    })
  ];
}
