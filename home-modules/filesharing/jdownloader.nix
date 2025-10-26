{ config, pkgs, ... }:

{
  home.packages = [
    (pkgs.jdownloader.override {
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
