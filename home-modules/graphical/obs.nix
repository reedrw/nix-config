{ pkgs, lib, config, ... }:

{
  home.packages = [ pkgs.obs-studio ];

  home.activation.themeOBS = let
    theme =
      if config.stylix.polarity == "light"
      then "com.obsproject.Yami.Light"
      else "com.obsproject.Yami.Dark";
  in config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if ! test -f "${config.xdg.configHome}/obs-studio/user.ini"; then
      mkdir -p "${config.xdg.configHome}/obs-studio"
      touch "${config.xdg.configHome}/obs-studio/user.ini"
    fi

    ${lib.getExe pkgs.crudini} --set "${config.xdg.configHome}/obs-studio/user.ini" Appearance Theme "${theme}"
  '';

  custom.persistence.directories = [
    ".config/obs-studio"
  ];
}
