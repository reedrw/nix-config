{ pkgs, ... }:

{
  stylix.targets.telegram-desktop.enable = true;

  home.packages = with pkgs; [
    (wrapEnv pkgs-unstable.telegram-desktop {
      XDG_CURRENT_DESKTOP = "gnome";
    })
  ];

  # doesn't do anything on i3, but needed for Telegram to close without minimizing
  # https://github.com/telegramdesktop/tdesktop/issues/27190#issuecomment-1840780300
  dconf.settings = {
    "org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
  };
}
