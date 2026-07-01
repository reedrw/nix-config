{ pkgs, ... }:

{
  stylix.targets.telegram-desktop.enable = true;

  home.packages = with pkgs; [
    (wrapEnv telegram-desktop {
      XDG_CURRENT_DESKTOP = "gnome";
      # stylix qt module breaks tdesktop right-click shadow
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "";
      QT_STYLE_OVERRIDE = "";
    })
  ];

  custom.persistence.directories = [
    ".local/share/TelegramDesktop"
  ];

  services.swaync.settings.notification-action-filter.telegram-hide-mark-as-read = {
    app-name     = "Telegram Desktop";
    use-regex    = true;
    text-matcher = "[Mm]ark [Aa]s [Rr]ead";
  };
}
