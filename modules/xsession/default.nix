{ config, lib, pkgs, ... }:
let
  term = "WINIT_X11_SCALE_FACTOR=1.0 alacritty";

  mod = "Mod1";
  sup = "Mod4";
  exec = "exec --no-startup-id";

  alwaysRun = with pkgs; [
    "${binPath feh} --bg-fill ~/.background-image"
    "systemctl --user restart picom"
    "systemctl --user restart autotiling"
    "systemctl --user restart easyeffects"
    "systemctl --user import-environment PATH"
    "systemctl --user restart xdg-desktop-portal.service"
    "xinput --disable $(xinput | grep -o 'Synaptics.*id=[0-9]*' | cut -d '=' -f 2)"
    "xinput --disable $(xinput | grep -o 'TouchPad.*id=[0-9]*' | cut -d '=' -f 2)"
    "xset r rate 250 50"
    "${binPath xorg.xmodmap} -e 'keycode 117 = XF86Forward'"
    "${binPath xorg.xmodmap} -e 'keycode 112 = XF86Back'"
  ];

  run = [
    "i3-msg workspace 1"
    "xrandr --output DisplayPort-1 --mode 1920x1080 --rate 144"
  ];

  scripts = import ./scripts { inherit pkgs; };

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
          inner = 5;
        };
        window.border = 5;
        window.titlebar = false;
        floating.border = 5;
        floating.titlebar = false;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = with pkgs; lib.mkOptionDefault (
          {
            "Print" = "${exec} flameshot gui";
            "${mod}+Return" = "${exec} ${term}";
            "${sup}+Return" = "${exec} ${scripts.selecterm}/bin/select-term.sh";
            "${mod}+d" = "focus child";
            "${mod}+o" = "open";
            "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
            "${sup}+Right" = "resize grow width 5 px or 5 ppt";
            "${sup}+Down" = "resize grow height 5 px or 5 ppt";
            "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
            "${sup}+space" = "${exec} ~/.config/rofi/roficomma.sh -lines 10 -width 40";
            "${mod}+r" = "${exec} ${scripts.record}/bin/record.sh";
            "${mod}+p" = "${exec} ${scripts.bwmenu-patched}/bin/bwmenu";
            "${mod}+Shift+s" = "sticky toggle";
            "XF86MonBrightnessUp" = "${exec} ${binPath brightnessctl} s 10%+";
            "XF86MonBrightnessDown" = "${exec} ${binPath brightnessctl} s 10%-";
            "Ctrl+Down" = "${exec} ${binPath playerctl} play-pause";
            "Ctrl+Left" = "${exec} ${binPath playerctl} previous";
            "Ctrl+Right" = "${exec} ${binPath playerctl} next";
            "XF86AudioPause" = "${exec} ${binPath playerctl} play-pause";
            "XF86AudioPlay" = "${exec} ${binPath playerctl} play-pause";
            "XF86AudioPrev" = "${exec} ${binPath playerctl} previous";
            "XF86AudioNext" = "${exec} ${binPath playerctl} next";
            "XF86AudioMute" = "${exec} ${binPath scripts.volume} mute";
            "XF86AudioRaiseVolume" = "${exec} ${binPath scripts.volume} up 5";
            "XF86AudioLowerVolume" = "${exec} ${binPath scripts.volume} down 5";
          } // lib.attrsets.mapAttrs' (x: y: lib.attrsets.nameValuePair
            ("${mod}+ctrl+${x}") ("${exec} ${scripts.load-layouts}/bin/load-layouts.sh ${x}")
          ) (builtins.listToAttrs (map
            (x: { name = toString x; value = x; } ) (lib.lists.range 0 9)
          ))
        );
        colors = with config.colorScheme.colors; {
          focused = {
            border = "#${base07}";
            childBorder = "#${base07}";
            background = "#${base07}";
            text = "#${base07}";
            indicator = "#${base07}";
          };
          focusedInactive = {
            border = "#${base03}";
            childBorder = "#${base03}";
            background = "#${base03}";
            text = "#${base03}";
            indicator = "#${base03}";
          };
          unfocused = {
            border = "#${base03}";
            childBorder = "#${base03}";
            background = "#${base03}";
            text = "#${base03}";
            indicator = "#${base03}";
          };
          urgent = {
            border = "#${base03}";
            childBorder = "#${base03}";
            background = "#${base00}";
            text = "#${base05}";
            indicator = "#${base00}";
          };
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
        ] ++ builtins.map ( class:
          {
            command = "border pixel 0";
            criteria = {
              inherit class;
            };
          }
        ) [
          "firefox"
          "mpv"
          "Alacritty"
          "TelegramDesktop"
          "Element"
          "discord"
          "Zathura"
        ];
        startup = []
        ++ builtins.map ( command:
          {
            inherit command;
            always = true;
            notification = false;
          }
        ) alwaysRun
        ++ builtins.map ( command:
          {
            inherit command;
            notification = false;
          }
        ) run;
      };
    };
  };
  services = {
    flameshot.enable = true;
  };
  home.file.".background-image".source = ./wallpaper.png;

  xdg.configFile = {
    "i3/workspace-1.json".source = ./workspace-1.json;
    "i3/workspace-2.json".source = ./workspace-2.json;
    "i3/workspace-4.json".source = ./workspace-4.json;
  };

  systemd.user.services = {
    clipboard-clean = {
      Unit = {
        After = [ "graphical.target" ];
        Description = "Clean URLS on clipboard using ClearURL rules.";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = with pkgs; {
        ExecStart = "${binPath scripts.clipboard-clean}";
        Restart = "on-failure";
        Type = "simple";
      };
    };
    autotiling = {
      Unit = {
        After = [ "graphical.target" ];
        Description = "Automatic tiling for i3/sway";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = with pkgs; {
        ExecStart = "${binPath autotiling}";
        Restart = "on-failure";
        Type = "simple";
      };
    };
    mpv-dnd = {
      Unit = {
        After = [ "graphical.target" ];
        Description = "Suspend chat apps while mpv is active so I can watch things in peace.";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = with pkgs; {
        ExecStart = "${binPath scripts.mpv-dnd}" + lib.concatMapStrings (x: " " + x) [
          "Discord"
          "telegram-deskt"
        ];
        Restart = "on-failure";
        Type = "simple";
      };
    };
  };
}
