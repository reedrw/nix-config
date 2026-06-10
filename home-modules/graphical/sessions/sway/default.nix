{ config, lib, pkgs, ... }:

let
  inherit (config.lib) scripts functions;

  # Commands to run on every sway (re)start
  alwaysRun = with pkgs; [
    "systemctl --user restart autotiling"
    "systemctl --user restart easyeffects"
    "systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user restart xdg-desktop-portal.service"
    "systemctl --user restart xdg-desktop-portal-gtk.service"
    "systemctl --user restart xdg-desktop-portal-wlr.service"
    "${lib.getExe scripts.toggle-touchpad} disable --silent"
  ];

  # Commands to run once at first sway start
  run = [
    "swaymsg workspace 1"
  ];

  commandForWindows = { command }: map (window: {
    inherit command;
    criteria = if builtins.isAttrs window then window else { app_id = window; };
  });

in
{
  imports = [
    ./keybinds.nix
    ../i3/config/xdgApps.nix
    ./scripts
    ./rofi
    ./noctalia
  ];

  home = {
    packages = with pkgs; [
      wl-clipboard
      grimblast
      rofimoji
      playerctl
    ];

    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "sway";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    activation.reloadSway = config.lib.dag.entryAfter ["writeBoundary"] ''
      if command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null 2>&1; then
        run swaymsg reload
      fi
    '';
  };

  programs.zsh.initContent = lib.mkAfter ''
    function c(){
      if [[ -p /dev/stdin ]]; then
        wl-copy
      else
        wl-paste
      fi
    }
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
  '';

  stylix.targets.sway.enable = true;

  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.swayfx.overrideAttrs (old: {
      passthru = (old.passthru or {}) // { providedSessions = [ "sway" ]; };
    });
    checkConfig = false;

    config = {
      modifier = "Mod1";
      terminal  = config.home.sessionVariables.TERMINAL;
      bars = [ ];

      gaps.inner = 7;

      fonts = lib.mkForce {
        names = [ "Fantasque Sans Mono" ];
        style = "Bold";
        size  = 10.0;
      };

      window = {
        border   = 5;
        titlebar = false;
        commands =
          commandForWindows { command = "floating enable"; } [
            "An Anime Game Launcher"
            "The Honkers Railway Launcher"
            "Honkers Launcher"
            "Sleepy Launcher"
            { app_id = "kitty"; title = "^float"; }
          ]
          ++ commandForWindows { command = "border pixel 0"; } [
            "signal"
            "org.telegram.desktop"
            "org.pwmt.zathura"
            "discord"
            "com.github.wwmm.easyeffects"
            "firefox"
            "kitty"
            "mpv"
          ]
          ++ commandForWindows { command = "fullscreen enable"; } [
            "mpv"
            { app_id = "org.telegram.desktop"; title = "Media viewer"; }
          ];
      };

      floating = {
        border   = 5;
        titlebar = false;
      };

      input = {
        "*" = {
          repeat_delay  = "250";
          repeat_rate   = "50";
          xkb_options   = "ctrl:nocaps";
          accel_profile = "flat";
          pointer_accel = "0.3";
        };
        "type:touchpad" = {
          natural_scroll = "enabled";
          tap            = "enabled";
        };
      };

      startup =
        map (command: { inherit command; always = true; }) alwaysRun
        ++ map (command: { inherit command; }) run;
    };

    # swayfx compositor effects (replaces picom)
    extraConfig = ''
      corner_radius 10
      shadows enable
      shadow_blur_radius 10
      shadow_color #00000066
      default_dim_inactive 0.05
    '';
  };

  systemd.user.services = lib.mergeAttrsList [
    (functions.mkSimpleService "autotiling-rs"   <| lib.getExe pkgs.autotiling-rs)
    (functions.mkSimpleService "clipboard-clean" <| "${pkgs.wl-clipboard}/bin/wl-paste --watch ${lib.getExe scripts.clipboard-clean}")
    (functions.mkSimpleService "dwebp-serv"      <| lib.getExe scripts.dwebp-serv)
    (functions.mkSimpleService "mpv-dnd"         <| lib.getExe scripts.mpv-dnd)
    (functions.mkSimpleService "solaar"          <| lib.getExe scripts.solaar)
    (functions.mkSimpleService "droidcam-fix"    <| lib.getExe scripts.droidcam-fix)
    (lib.recursiveUpdate
      (functions.mkSimpleService "noctalia-shell" <| lib.getExe pkgs.noctalia-shell)
      { noctalia-shell.Service.Environment = "QT_QPA_PLATFORM=wayland"; })
  ];
}
