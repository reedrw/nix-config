{ config, lib, pkgs, ... }:
let
  term = "${config.home.sessionVariables.TERMINAL}";

  mod = "Mod1";
  sup = "Mod4";
  exec = "exec --no-startup-id";

  alwaysRun = with pkgs; [
    "${lib.getExe feh} --bg-fill ${./wallpaper.jpg}"
    "systemctl --user restart picom"
    "systemctl --user restart autotiling"
    "systemctl --user restart easyeffects"
    "systemctl --user restart playerctld"
    "systemctl --user import-environment PATH"
    "systemctl --user restart xdg-desktop-portal.service"
    "${lib.getExe scripts.toggle-touchpad} disable --silent"
  ];

  run = [
    "i3-msg workspace 1"
  ];

  # Window classes to be suspended while mpv is the active window
  chatApps = [
    "TelegramDesktop"
    "VencordDesktop"
  ];

  scripts = import ./scripts pkgs;

in
{
  xsession = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3;
      config = {
        bars = [ ];
        gaps = {
          inner = 7;
        };
        window.border = 5;
        window.titlebar = false;
        floating.border = 5;
        floating.titlebar = false;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = with pkgs; lib.mkOptionDefault ({
          "Print" = "${exec} flameshot gui";
          "${mod}+Escape" = "${exec} ${lib.getExe scripts.pause-suspend}";
          "${mod}+Return" = "${exec} ${term}";
          "${sup}+Return" = "${exec} ${lib.getExe scripts.select-term}";
          "${mod}+d" = "focus child";
          "${mod}+o" = "open";
          "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
          "${sup}+Right" = "resize grow width 5 px or 5 ppt";
          "${sup}+Down" = "resize grow height 5 px or 5 ppt";
          "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
          "${sup}+space" = "${exec} ~/.config/rofi/roficomma.sh -lines 10 -width 40";
          "${mod}+r" = "${exec} ${lib.getExe scripts.record}";
          "${mod}+Shift+s" = "sticky toggle";
          "${mod}+2" = "${exec} ${writeShellScript "workspace2" ''
            i3-msg workspace 2
            ${lib.getExe scripts.mpv-dnd} --resume ${builtins.concatStringsSep " " chatApps}
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
        ]);
        colors = with config.colorScheme.colors; let
          focused = {
            border = "#${base07}";
            childBorder = "#${base07}";
            background = "#${base07}";
            text = "#${base07}";
            indicator = "#${base07}";
          };
          inactive = {
            border = "#${base03}";
            childBorder = "#${base03}";
            background = "#${base03}";
            text = "#${base03}";
            indicator = "#${base03}";
          };
        in {
          inherit focused;
          focusedInactive = inactive;
          unfocused = inactive;
          urgent = inactive;
        };
        window.commands = [
          {
            command = "floating enable";
            criteria = {
              class = "Alacritty";
              title = "float";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "An Anime Game Launcher";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "The Honkers Railway Launcher";
            };
          }
        ] ++ map ( class: {
          command = "border pixel 0";
          criteria = {
            inherit class;
          };
        }) [
          "firefox"
          "mpv"
          "Alacritty"
          "kitty"
          "TelegramDesktop"
          "Element"
          "easyeffects"
          "vesktop"
          "Pavucontrol"
          "Zathura"
          ".blueman-manager-wrapped"
          ".gamescope-wrapped"
        ];
        startup = map ( command: {
          inherit command;
          always = true;
          notification = false;
        }) alwaysRun ++ map ( command: {
          inherit command;
          notification = false;
        }) run;
      };
    };
  };

  services.flameshot.enable = true;

  xdg.configFile = {
    "i3/workspace-1.json".source = ./workspace-1.json;
    "i3/workspace-2.json".source = ./workspace-2.json;
    "i3/workspace-4.json".source = ./workspace-4.json;
  };

  systemd.user.services = with pkgs; mergeAttrs [
    (mkSimpleHMService "autotiling" "${lib.getExe autotiling}")
    (mkSimpleHMService "clipboard-clean" "${lib.getExe scripts.clipboard-clean}")
    (mkSimpleHMService "dwebp-serv" "${lib.getExe scripts.dwebp-serv}")
    (mkSimpleHMService "mpv-dnd" "${lib.getExe scripts.mpv-dnd} ${builtins.concatStringsSep " " chatApps}")
    (mkSimpleHMService "keybinds" "${lib.getExe scripts.keybinds}")
  ];
}
