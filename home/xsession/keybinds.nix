{ config, osConfig, pkgs, lib,  ... }:
let
  term = "${config.home.sessionVariables.TERMINAL}";
  scripts = config.lib.scripts;

  mod = config.xsession.windowManager.i3.config.modifier;
  sup = "Mod4";
  exec = "exec --no-startup-id";
in
with lib;
with pkgs;
{ xsession.windowManager.i3.config.keybindings = mkOptionDefault ({
  "Print" = "${exec} flameshot gui";
  "${mod}+Escape" = "${exec} ${getExe scripts.pause-suspend}";
  "${mod}+Return" = "${exec} ${term}";
  "${sup}+Return" = "${exec} ${getExe scripts.select-term}";
  "${mod}+d" = "focus child";
  "${mod}+o" = "open";
  "${mod}+l" = "${exec} ${getExe lockProgram}";
  "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
  "${sup}+Right" = "resize grow width 5 px or 5 ppt";
  "${sup}+Down" = "resize grow height 5 px or 5 ppt";
  "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
  "${sup}+space" = "${exec} ${getExe scripts.roficomma} -lines 10 -width 40";
  "${mod}+r" = "${exec} ${getExe scripts.record}";
  "${mod}+n" = "${exec} ${osConfig.services.mullvad-vpn.package}/bin/mullvad reconnect";
  "${mod}+Shift+s" = "sticky toggle";
  "${mod}+2" = "${exec} ${writeShellScript "workspace2" ''
    i3-msg workspace 2
    ${getExe scripts.mpv-dnd} --resume
  ''}";
  "${mod}+${sup}+space" = "${exec} ${getExe scripts.toggle-touchpad}";
  "XF86MonBrightnessUp" = "${exec} ${getExe scripts.brightness} up 15";
  "XF86MonBrightnessDown" = "${exec} ${getExe scripts.brightness} down 15";
  "Ctrl+Down" = "${exec} ${getExe playerctl} play-pause";
  "Ctrl+Left" = "${exec} ${getExe playerctl} previous";
  "Ctrl+Right" = "${exec} ${getExe playerctl} next";
  "XF86AudioPause" = "${exec} ${getExe playerctl} play-pause";
  "XF86AudioPlay" = "${exec} ${getExe playerctl} play-pause";
  "XF86AudioPrev" = "${exec} ${getExe playerctl} previous";
  "XF86AudioNext" = "${exec} ${getExe playerctl} next";
  "XF86AudioMute" = "${exec} ${getExe scripts.volume} mute";
  "XF86AudioRaiseVolume" = "${exec} ${getExe scripts.volume} up 5";
  "XF86AudioLowerVolume" = "${exec} ${getExe scripts.volume} down 5";
} // pipe (range 0 9) [
  (map toString)
  (map (n: {"${mod}+ctrl+${n}" = "${exec} ${getExe scripts.load-layouts} ${n}";}))
  mergeAttrsList
]); }
