{ pkgs, ... }:

{
  stylix.targets.telegram-desktop.enable = true;

  home.packages = with pkgs; [
    (wrapEnv pkgs-unstable.telegram-desktop {
      XDG_CURRENT_DESKTOP = "gnome";
      # stylix qt module breaks tdesktop right-click shadow
      QT_QPA_PLATFORMTHEME = "";
      QT_STYLE_OVERRIDE = "";
    })
  ];

  # doesn't do anything on i3, but needed for Telegram to close without minimizing
  # https://github.com/telegramdesktop/tdesktop/issues/27190#issuecomment-1840780300
  dconf.settings = {
    "org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
  };

  custom.persistence.directories = [
    ".local/share/TelegramDesktop"
  ];
}
