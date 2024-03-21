{ config, osConfig, pkgs, lib,  ... } @ args:
let
  term = "${config.home.sessionVariables.TERMINAL}";
  scripts = pkgs.callPackage ./scripts args;

  mod = config.xsession.windowManager.i3.config.modifier;
  sup = "Mod4";
  exec = "exec --no-startup-id";
in
{ xsession.windowManager.i3.config.keybindings = with pkgs; lib.mkOptionDefault ({
  "Print" = "${exec} flameshot gui";
  "${mod}+Escape" = "${exec} ${lib.getExe scripts.pause-suspend}";
  "${mod}+Return" = "${exec} ${term}";
  "${sup}+Return" = "${exec} ${lib.getExe scripts.select-term}";
  "${mod}+d" = "focus child";
  "${mod}+o" = "open";
  "${mod}+l" = "${exec} ${pkgs.i3lock-fancy}/bin/i3lock";
  "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
  "${sup}+Right" = "resize grow width 5 px or 5 ppt";
  "${sup}+Down" = "resize grow height 5 px or 5 ppt";
  "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
  "${sup}+space" = "${exec} ~/.config/rofi/roficomma.sh -lines 10 -width 40";
  "${mod}+r" = "${exec} ${lib.getExe scripts.record}";
  "${mod}+n" = "${exec} ${osConfig.services.mullvad-vpn.package}/bin/mullvad reconnect";
  "${mod}+Shift+s" = "sticky toggle";
  "${mod}+2" = "${exec} ${writeShellScript "workspace2" ''
    i3-msg workspace 2
    ${lib.getExe scripts.mpv-dnd} --resume
  ''}";
  "${mod}+${sup}+space" = "${exec} ${lib.getExe scripts.toggle-touchpad}";
  "XF86MonBrightnessUp" = "${exec} ${lib.getExe brightnessctl} s 10%+";
  "XF86MonBrightnessDown" = "${exec} ${lib.getExe brightnessctl} s 10%-";
  "Ctrl+Down" = "${exec} ${lib.getExe playerctl} play-pause";
  "Ctrl+Left" = "${exec} ${lib.getExe playerctl} previous";
  "Ctrl+Right" = "${exec} ${lib.getExe playerctl} next";
  "XF86AudioPause" = "${exec} ${lib.getExe playerctl} play-pause";
  "XF86AudioPlay" = "${exec} ${lib.getExe playerctl} play-pause";
  "XF86AudioPrev" = "${exec} ${lib.getExe playerctl} previous";
  "XF86AudioNext" = "${exec} ${lib.getExe playerctl} next";
  "XF86AudioMute" = "${exec} ${lib.getExe scripts.volume} mute";
  "XF86AudioRaiseVolume" = "${exec} ${lib.getExe scripts.volume} up 5";
  "XF86AudioLowerVolume" = "${exec} ${lib.getExe scripts.volume} down 5";
} // lib.pipe (lib.range 0 9) [
  (map toString)
  (map (n: {"${mod}+ctrl+${n}" = "${exec} ${lib.getExe scripts.load-layouts} ${n}";}))
  (mergeAttrs)
]); }
