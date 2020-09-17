{ config, lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      libsForQt5.qtstyleplugins
      adwaita-qt
      qt5.qtbase
      papirus-icon-theme
      qt5ct
    ];

    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
    };
  };

  xdg.configFile = {
    "gtk-3.0/settings.ini".source = ./settings.ini;
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
    "Trolltech.conf".text = ''
      [Qt]
      font="Sans Serif,9,-1,5,50,0,0,0,0,0"
      Palette\active=#abb2bf, #282c34, #323741, #2d313a, #1e2128, #21242b, #abb2bf, #ffffff, #abb2bf, #ffffff, #282c34, #000000, #000080, #ffffff, #0000ff, #ff00ff, #939599, #000000, #ffffdc, #000000
      Palette\inactive=#abb2bf, #282c34, #323741, #2d313a, #1e2128, #21242b, #abb2bf, #ffffff, #abb2bf, #ffffff, #282c34, #000000, #000080, #ffffff, #0000ff, #ff00ff, #939599, #000000, #ffffdc, #000000
      Palette\disabled=#696f79, #282c34, #323741, #2d313a, #1e2128, #1a1d22, #696f79, #ffffff, #696f79, #ffffff, #282c34, #000000, #000080, #ffffff, #0000ff, #ff00ff, #939599, #000000, #ffffdc, #000000
      fontPath=@Invalid()
      embedFonts=true
      style=GTK+
      doubleClickInterval=400
      cursorFlashTime=1000
      wheelScrollLines=3
      resolveSymlinks=false
      globalStrut\width=0
      globalStrut\height=0
      useRtlExtensions=false
      XIMInputStyle=On The Spot
      DefaultInputMethod=xim
      audiosink=Auto
      videomode=Auto
      GUIEffects=none
    '';
  };
}
