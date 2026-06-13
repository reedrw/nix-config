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

  # Portal backends under sway:
  #   wlr      — ScreenCast, Screenshot
  #   hyprland — GlobalShortcuts (works on any wlroots compositor)
  #   gnome    — Background, Clipboard, InputCapture, RemoteDesktop, Usb
  #   gnome-keyring — Secret (provided by the gnome-keyring daemon)
  # gtk (added in nixos-modules/core/tweaks.nix) handles everything else.
  # Inhibit is intentionally left as "none" by NixOS's sway module — see
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/wayland/sway.nix
  xdg.portal = {
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gnome
    ];
    wlr.enable = true;
    config.sway = {
      "org.freedesktop.impl.portal.GlobalShortcuts" = "hyprland";
      "org.freedesktop.impl.portal.Background"     = "gnome";
      "org.freedesktop.impl.portal.Clipboard"      = "gnome";
      "org.freedesktop.impl.portal.InputCapture"   = "gnome";
      "org.freedesktop.impl.portal.RemoteDesktop"  = "gnome";
      "org.freedesktop.impl.portal.Usb"            = "gnome";
      "org.freedesktop.impl.portal.Secret"         = "gnome-keyring";
    };
  };

  # Installs the gnome-keyring `.portal` file system-wide so the Secret
  # portal interface is registered. The daemon itself is started per-user
  # via home-modules/extra/gnome-keyring.nix.
  services.gnome.gnome-keyring.enable = true;

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
