{ inputs, config, pkgs, ... }:

with inputs.nix-colors;
{
  imports = [ homeManagerModule ];
  colorScheme = colorSchemes. horizon-terminal-dark;

  home = {
    packages = with pkgs; [
      adwaita-qt
      libsForQt5.qtstyleplugins
      papirus-icon-theme
      qt5.qtbase
      qt5ct
    ];

    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
      XCURSOR_THEME = config.gtk.cursorTheme.name;
    };
  };

  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.gnome.adwaita-icon-theme;
    # name = "Vanilla-DMZ-AA";
    # package = pkgs.vanilla-dmz;
    size = 24;
    # name = "Quintom_Ink";
    # package = pkgs.quintom-cursor-theme;
    gtk.enable = true;
    x11 = {
      enable = true;
      #defaultCursor = "Vanilla-DMZ-AA";
      defaultCursor = "Adwaita";
    };
  };

  xdg.configFile = {
    "Trolltech.conf".source = ./Trolltech.conf;
    #"gtk-3.0/settings.ini".source = ./settings.ini;
    "qt5ct/qt5ct.conf".text = ''
      [Appearance]
      color_scheme_path=${pkgs.qt5ct}/share/qt5ct/colors/airy.conf
      custom_palette=false
      icon_theme=Papirus-Dark
      standard_dialogs=default
      style=Adwaita-Dark

      [Fonts]
      fixed=@Variant(\0\0\0@\0\0\0\x14\0S\0\x61\0n\0s\0 \0S\0\x65\0r\0i\0\x66@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
      general=@Variant(\0\0\0@\0\0\0\x14\0S\0\x61\0n\0s\0 \0S\0\x65\0r\0i\0\x66@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

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
    "gtk-4.0/gtk.css".text = ''
      window {
        padding: 0;
        box-shadow: none;
      }
    '';
    "gtk-3.0/gtk.css".text = ''
      decoration {
        padding: 0;
      }
    '';
  };

  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      inherit (config.home.pointerCursor) name package size;
    };
    gtk2.extraConfig = ''
      gtk-application-prefer-dark-theme = true
    '';
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "Cantarell 10";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle= "hintmedium";
      gtk-decoration-layout = ":";
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };
  dconf.settings."org/freedesktop/appearance" = {
    color-scheme = 1;
  };
}
