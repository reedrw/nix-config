{ config, pkgs, ... }:

{
  home.packages = [
    (pkgs.jdownloader.override {
      darkTheme = true;
      debloat = true;
      extraOptions = {
        "org.jdownloader.extensions.extraction.ExtractionExtension" = {
          deletearchivefilesafterextractionaction = "NULL";
        };
        "org.jdownloader.settings.GeneralSettings" = {
          defaultdownloadfolder = "${config.xdg.dataHome}/jdownloader/downloads";
        };
      };
    })
  ];
}
