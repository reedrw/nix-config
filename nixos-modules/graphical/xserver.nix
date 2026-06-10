{ pkgs, ... }:

{
  programs.dconf.enable = true;

  programs.sway = lib.mkIf isSway {
    enable = true;
    package = pkgs.swayfx.overrideAttrs (old: {
      passthru = (old.passthru or {}) // {
        providedSessions = [ "sway" ];
      };
    });
  };

  # xdg-desktop-portal-wlr handles screensharing / screencast under sway.
  xdg.portal = lib.mkIf isSway {
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    wlr.enable   = true;
  };

  services = {
    # Remap PageUp/Down → XF86Back/Forward and Shift+Esc → tilde.
    # CapsLock → Ctrl is handled in sway's xkb_options (ctrl:nocaps).
    keyd = lib.mkIf isSway {
      enable = true;
      keyboards.default.settings = {
        main  = { "pageup" = "back"; "pagedown" = "forward"; };
        shift = { "esc" = "~"; };
      };
    };

    displayManager = {
      defaultSession = "sway";
      gdm.enable = true;
    };

    xserver = lib.mkIf isX11 {
      enable = true;
      displayManager.session = lib.optionals (!config.services.desktopManager.gnome.enable) [
        {
          manage = "desktop";
          name = "xsession";
          start = ''exec $HOME/.local/share/X11/xsession'';
        }
      ];
    };
  };
}
