{ pkgs, ... }:

{
  programs.dconf.enable = true;

  programs.sway = {
    enable = true;
    package = pkgs.swayfx.overrideAttrs (old: {
      passthru = (old.passthru or {}) // {
        providedSessions = [ "sway" ];
      };
    });
  };

  # xdg-desktop-portal-wlr handles screensharing / screencast under sway.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    wlr.enable   = true;
  };

  services = {
    keyd = {
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
  };
}
