{ ... }:
{
  services.picom = {
    enable = true;
    extraArgs = [ "--legacy-backends" ];
    shadow = true;
    fade = true;
    fadeDelta = 3;
    shadowOpacity = 0.3;
    shadowExclude = [
      "! name      ~= ''"
      "name         = '[i3 con] workspace 1'"
      "name         = '[i3 con] workspace 2'"
      "name         = '[i3 con] workspace 3'"
      "name         = '[i3 con] workspace 4'"
      "name         = '[i3 con] workspace 5'"
      "name         = '[i3 con] workspace 6'"
      "name         = '[i3 con] workspace 7'"
      "name         = '[i3 con] workspace 8'"
      "name         = '[i3 con] workspace 9'"
      "name         = '[i3 con] workspace 10'"
      "name         = 'bar'"
      "name         = 'Notification'"
      "class_g     ?= 'Notify-osd'"
      "class_g      = 'Cairo-clock'"
      "class_g      = 'slop'"
      "window_type *= 'menu'"
      "_GTK_FRAME_EXTENTS@:c"
      "_NET_WM_WINDOW_TYPE:a *= '_KDE_NET_WM_WINDOW_TYPE_OVERRIDE'"
    ];
    settings = {
      corner-radius = 10;
      shadow-radius = 20;
      rounded-corners-exclude = [
        "class_g = 'Polybar'"
      ];
    };
  };
}
