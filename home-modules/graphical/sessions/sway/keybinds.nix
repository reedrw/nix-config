{ config, osConfig, pkgs, lib, ... }:

let
  inherit (config.lib) scripts;
  term = config.home.sessionVariables.TERMINAL;

  mod = config.wayland.windowManager.sway.config.modifier;
  sup = "Mod4";
in
with lib;
with pkgs;
{
  wayland.windowManager.sway.config.keybindings = mkOptionDefault ({
    "Print"                    = "exec flameshot gui";
    "${mod}+Return"            = "exec ${term}";
    "${sup}+Return"            = "exec ${getExe scripts.select-term}";
    "${mod}+d"                 = "focus child";
    "${mod}+o"                 = "open";
    "${mod}+l"                 = "exec loginctl lock-session";
    "${sup}+Left"              = "resize shrink width 5 px or 5 ppt";
    "${sup}+Right"             = "resize grow width 5 px or 5 ppt";
    "${sup}+Down"              = "resize grow height 5 px or 5 ppt";
    "${sup}+Up"                = "resize shrink height 5 px or 5 ppt";
    "${sup}+space"             = "exec ${getExe scripts.wofi-comma}";
    "${mod}+r"                 = "exec ${getExe scripts.record}";
    "${mod}+n"                 = "exec ${osConfig.services.mullvad-vpn.package}/bin/mullvad reconnect";
    "${mod}+Shift+semicolon"   = "exec ${getExe pkgs.wofi-emoji}";
    "${mod}+Shift+s"           = "sticky toggle";
    "${mod}+Shift+r"           = "reload";
    "${mod}+Shift+q"           = "kill";
    "${mod}+2"                 = "exec ${writeShellScript "workspace2" ''
      swaymsg workspace 2
      ${getExe scripts.mpv-dnd} --resume
    ''}";
    "${mod}+${sup}+space"      = "exec ${getExe scripts.toggle-touchpad}";
    "XF86MonBrightnessUp"      = "exec ${getExe scripts.brightness} up 15";
    "XF86MonBrightnessDown"    = "exec ${getExe scripts.brightness} down 15";
    "Ctrl+Down"                = "exec ${getExe playerctl} play-pause";
    "Ctrl+Left"                = "exec ${getExe playerctl} previous";
    "Ctrl+Right"               = "exec ${getExe playerctl} next";
    "XF86AudioPause"           = "exec ${getExe playerctl} play-pause";
    "XF86AudioPlay"            = "exec ${getExe playerctl} play-pause";
    "XF86AudioPrev"            = "exec ${getExe playerctl} previous";
    "XF86AudioNext"            = "exec ${getExe playerctl} next";
    "XF86AudioMute"            = "exec ${getExe scripts.volume} mute";
    "XF86AudioRaiseVolume"     = "exec ${getExe scripts.volume} up 5";
    "XF86AudioLowerVolume"     = "exec ${getExe scripts.volume} down 5";
  } // (range 0 9
    |> map toString
    |> map (n: { "${mod}+ctrl+${n}" = ''exec sh -c 'swaymsg "workspace ${n}" && ${getExe scripts.load-layouts} ${n}' ''; })
    |> mergeAttrsList
  ));
}
