{ inputs, config, osConfig, pkgs, lib, ... }:

{

  imports = [
    inputs.stylix.homeModules.stylix
    ./extra/prismlauncher.nix
    ./extra/steam.nix
    ./extra/telegram-desktop.nix
    ./extra/vesktop-clienttheme.nix
    {
      stylix = {
        inherit (osConfig.stylix)
          enable
          autoEnable
          base16Scheme
          image
          cursor
          fonts
          icons
        ;
      };
    }
  ];


  home = {
    packages = with pkgs; [
      adwaita-qt
      adwaita-qt6
      libsForQt5.qtstyleplugins
      qt5.qtbase
      libsForQt5.qt5ct
      qt6Packages.qt6ct
    ];

    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
      XCURSOR_THEME = config.gtk.cursorTheme.name;
    };
  };

  stylix.targets = {
    gtk.enable = true;
    qt.enable = true;
  };


  gtk = {
    enable = true;
    gtk2 = {
      configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc-2.0";
      extraConfig = ''
        gtk-application-prefer-dark-theme = ${toString <| config.stylix.polarity == "dark"}
      '';
    };
    gtk3.extraConfig = {
      gtk-font-name = "${config.stylix.fonts.sansSerif.name} ${toString config.stylix.fonts.sizes.applications}";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
      gtk-decoration-layout = ":close";
    };
    gtk4.extraConfig = {
      gtk-font-name = "${config.stylix.fonts.sansSerif.name} ${toString config.stylix.fonts.sizes.applications}";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
      gtk-decoration-layout = ":close";
    };
  };

  home.pointerCursor.dotIcons.enable = false;

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-${config.stylix.polarity}";
    "org/freedesktop/appearance".color-scheme = let
      inherit (config.stylix) polarity;
    in
      if polarity == "dark"
      then 1
      else
        if polarity == "light"
        then 2
        else 0;
  };
}
