{ inputs, config, osConfig, pkgs, ... }:

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
        ;
      };
    }
  ];


  home = {
    packages = with pkgs; [
      adwaita-qt
      adwaita-qt6
      libsForQt5.qtstyleplugins
      papirus-icon-theme
      qt5.qtbase
      libsForQt5.qt5ct
      qt6ct
    ];

    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
      XCURSOR_THEME = config.gtk.cursorTheme.name;
    };
  };

  stylix.targets.gtk = {
    enable = true;
    extraCss = ''
      window {
        padding: 0;
        box-shadow: none;
      }
      decoration {
        padding: 0;
        border: 0px;
      }
    '';
  };

  xdg.configFile = {
    "Trolltech.conf".source = ./Trolltech.conf;
    "qt5ct/qt5ct.conf".text = ''
      [Appearance]
      color_scheme_path=${pkgs.libsForQt5.qt5ct}/share/qt5ct/colors/airy.conf
      custom_palette=false
      icon_theme=Papirus-Dark
      standard_dialogs=default
      style=Adwaita-Dark

      [Fonts]
      fixed="Monospace,9,-1,5,50,0,0,0,0,0"
      general="Sans Serif,9,-1,5,50,0,0,0,0,0"

      [Interface]
      activate_item_on_single_click=1
      buttonbox_layout=0
      cursor_flash_time=1000
      dialog_buttons_have_icons=1
      double_click_interval=400
      gui_effects=@Invalid()
      keyboard_scheme=2
      menus_have_icons=true
      show_shortcuts_in_context_menus=true
      stylesheets=@Invalid()
      toolbutton_style=4
      underline_shortcut=1
      wheel_scroll_lines=3

      [SettingsWindow]
      geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\0\xc1\0\0\x1\f\0\0\x3\xa9\0\0\x3\xdb\0\0\0\xc6\0\0\x1\x11\0\0\x3\xa4\0\0\x3\xd6\0\0\0\0\0\0\0\0\a\x80\0\0\0\xc6\0\0\x1\x11\0\0\x3\xa4\0\0\x3\xd6)
    '';
    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      color_scheme_path=${pkgs.qt6ct}/share/qt5ct/colors/airy.conf
      custom_palette=false
      standard_dialogs=default
      style=Adwaita-Dark

      [Fonts]
      fixed="Monospace,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
      general="Sans Serif,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

      [Interface]
      activate_item_on_single_click=1
      buttonbox_layout=0
      cursor_flash_time=1000
      dialog_buttons_have_icons=1
      double_click_interval=400
      gui_effects=@Invalid()
      keyboard_scheme=2
      menus_have_icons=true
      show_shortcuts_in_context_menus=true
      stylesheets=@Invalid()
      toolbutton_style=4
      underline_shortcut=1
      wheel_scroll_lines=3

      [SettingsWindow]
      geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\0\a\0\0\x2-\0\0\x3\xbc\0\0\x4\x30\0\0\0\f\0\0\x2\x32\0\0\x3\xb7\0\0\x4+\0\0\0\0\0\0\0\0\a\x80\0\0\0\f\0\0\x2\x32\0\0\x3\xb7\0\0\x4+)

      [Troubleshooting]
      force_raster_widgets=1
      ignored_applications=@Invalid()
    '';
  };

  gtk = {
    enable = true;
    # theme.name = "Adwaita-dark";
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk2 = {
      configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc-2.0";
      extraConfig = ''
        gtk-application-prefer-dark-theme = true
      '';
    };
    gtk3.extraConfig = {
      gtk-font-name = "Cantarell 10";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
      gtk-decoration-layout = ":close";
    };
    gtk4.extraConfig = {
      gtk-font-name = "Cantarell 10";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
      gtk-decoration-layout = ":close";
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
    "org/freedesktop/appearance".color-scheme = 1;
  };
}
