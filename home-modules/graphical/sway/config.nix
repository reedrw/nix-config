{ config, lib, pkgs, osConfig, ... }:

let
  inherit (config.lib) scripts functions;
  inherit (osConfig.custom.display) dp;

  wallpaper-colored = let
    fileType = config.stylix.image
      |> lib.splitString "."
      |> lib.last;
    filename = "wallpaper.${fileType}";
    colorScheme = config.lib.stylix.colors
      |> lib.getAttrs [
        "base00" "base01" "base02" "base03"
        "base04" "base05" "base06" "base07"
        "base08" "base09" "base0A" "base0B"
        "base0C" "base0D" "base0E" "base0F"
      ]
      |> builtins.attrValues
      |> builtins.concatStringsSep " "
    ;
  in pkgs.runCommand filename { buildInputs = with pkgs; [ lutgen imagemagick ]; } <|
  ((lib.optionalString (config.stylix.polarity == "light") ''
    convert ${config.stylix.image} -channel RGB -negate out.${fileType}
  '') + ''
    if test -f "out.${fileType}"; then
      image="out.${fileType}"
    else
      image="${config.stylix.image}"
    fi

    lutgen apply \
      -R \
      --preserve \
      -s 128 \
      $image \
      -o $out -- ${colorScheme}
  '');

  # Commands to run on every sway (re)start
  alwaysRun = [
    "systemctl --user restart autotiling"
    "systemctl --user restart easyeffects"
    "systemctl --user restart swaync"
    "systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user restart xdg-desktop-portal.service"
    "systemctl --user restart xdg-desktop-portal-gtk.service"
    "systemctl --user restart xdg-desktop-portal-wlr.service"
    "systemctl --user restart authentication-agent.service"
    "${lib.getExe scripts.toggle-touchpad} disable --silent"
    "sh -c 'sleep 1 && systemctl --user restart swaybg'"
    "sh -c 'sleep 1 && systemctl --user restart waybar'"
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
    ./xdgApps.nix
  ];

  home = {
    packages = with pkgs; [
      wl-clipboard
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

      gaps.inner = dp 7;

      fonts = lib.mkForce {
        names = [ "Fantasque Sans Mono" ];
        style = "Bold";
        size  = (dp 10) * 1.0;
      };

      window = {
        border   = dp 5;
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
            "bluetuith"
            "org.telegram.desktop"
            "org.pwmt.zathura"
            "discord"
            "com.github.wwmm.easyeffects"
            "com.saivert.pwvucontrol"
            "firefox"
            "kitty"
            "mpv"
            { instance = "steamwebhelper"; }
          ]
          ++ commandForWindows { command = "fullscreen enable"; } [
            "mpv"
            { app_id = "org.telegram.desktop"; title = "Media viewer"; }
          ];
      };

      floating = {
        border   = dp 5;
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
      corner_radius ${toString (dp 10)}
      shadows enable
      shadow_blur_radius ${toString (dp 20)}
      shadow_color #00000066
      layer_effects "waybar" {
        shadows enable;
      }
    ''
    + (
      if (config.stylix.polarity == "light")
      then ''
        default_dim_inactive 0.01
      '' else ''
        default_dim_inactive 0.05
      ''
    );
  };

  systemd.user.services = lib.mergeAttrsList [
    (functions.mkSimpleService "autotiling-rs"   <| lib.getExe pkgs.autotiling-rs)
    (functions.mkSimpleService "clipboard-clean" <| "${pkgs.wl-clipboard}/bin/wl-paste --watch ${lib.getExe scripts.clipboard-clean}")
    (functions.mkSimpleService "dwebp-serv"      <| lib.getExe scripts.dwebp-serv)
    (functions.mkSimpleService "mpv-dnd"         <| lib.getExe scripts.mpv-dnd)
    (functions.mkSimpleService "solaar"          <| lib.getExe scripts.solaar)
    (functions.mkSimpleService "swaybg"          <| "${lib.getExe pkgs.swaybg} -i ${wallpaper-colored}")
    (functions.mkSimpleService "droidcam-fix"    <| lib.getExe scripts.droidcam-fix)
  ];
}
