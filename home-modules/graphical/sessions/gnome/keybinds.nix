{
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Shift><Alt>q"];
      maximize = [];
      unmaximize = [];
      toggle-fullscreen = ["<Alt>f"];
      switch-to-workspace-1 = ["<Alt>1"];
      switch-to-workspace-2 = ["<Alt>2"];
      switch-to-workspace-3 = ["<Alt>3"];
      switch-to-workspace-4 = ["<Alt>4"];
      switch-to-workspace-5 = ["<Alt>5"];
      switch-to-workspace-6 = ["<Alt>6"];
      switch-to-workspace-7 = ["<Alt>7"];
      switch-to-workspace-8 = ["<Alt>8"];
      switch-to-workspace-9 = ["<Alt>9"];
      switch-to-workspace-10 = ["<Alt>0"];
      move-to-workspace-1 = ["<Shift><Alt>1"];
      move-to-workspace-2 = ["<Shift><Alt>2"];
      move-to-workspace-3 = ["<Shift><Alt>3"];
      move-to-workspace-4 = ["<Shift><Alt>4"];
      move-to-workspace-5 = ["<Shift><Alt>5"];
      move-to-workspace-6 = ["<Shift><Alt>6"];
      move-to-workspace-7 = ["<Shift><Alt>7"];
      move-to-workspace-8 = ["<Shift><Alt>8"];
      move-to-workspace-9 = ["<Shift><Alt>9"];
      move-to-workspace-10 = ["<Shift><Alt>0"];
    };
    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [];
      toggle-tiled-right = [];
    };
    "org/gnome/desktop/wm/preferences" = {
      resize-with-right-button = true;
      mouse-button-modifier = "<Alt>";
    };
    "org/gnome/shell/extensions/forge/keybindings" = {
      window-toggle-float = ["<Shift><Alt>Space"];

      window-focus-down = ["<Alt>Down"];
      window-focus-up = ["<Alt>Up"];
      window-focus-left = ["<Alt>Left"];
      window-focus-right = ["<Alt>Right"];

      window-move-down = ["<Shift><Alt>Down"];
      window-move-up = ["<Shift><Alt>Up"];
      window-move-left = ["<Shift><Alt>Left"];
      window-move-right = ["<Shift><Alt>Right"];

      window-resize-top-increase = ["<Super>Up"];
      window-resize-top-decrease = ["<Super>Down"];

      window-resize-right-increase = ["<Super>Right"];
      window-resize-right-decrease = ["<Super>Left"];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Terminal";
      binding = "<Alt>Return";
      command = "sh -c 'exec $TERMINAL'";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      previous = ["<Ctrl>Left" "XF86AudioPrev"];
      play = ["<Ctrl>Down" "XF86AudioPlay"];
      next = ["<Ctrl>Right" "XF86AudioNext"];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
  };
}
