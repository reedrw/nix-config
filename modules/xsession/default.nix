{ config, lib, pkgs, ... }:
let
  term = "WINIT_X11_SCALE_FACTOR=1.0 alacritty";

  mod = "Mod1";
  sup = "Mod4";
  exec = "exec --no-startup-id";

  alwaysRun = [
    "${pkgs.feh}/bin/feh --bg-fill ~/.background-image"
    "systemctl --user restart picom"
    "xinput --disable $(xinput | grep -o 'Synaptics.*id=[0-9]*' | cut -d '=' -f 2)"
    "xinput --disable $(xinput | grep -o 'TouchPad.*id=[0-9]*' | cut -d '=' -f 2)"
    "xset r rate 250 50"
  ];

  load-layouts = pkgs.writeShellApplication {
    name = "load-layouts.sh";
    runtimeInputs = [ pkgs.wmctrl ];
    text = (builtins.readFile ./load-layouts.sh);
  };

  run = [
    "${load-layouts}/bin/load-layouts.sh"
  ];

  selecterm = pkgs.writeShellApplication {
    name = "select-term.sh";
    runtimeInputs = [ pkgs.slop ];
    text = (builtins.readFile ./select-term.sh);
  };

  record = pkgs.writeShellApplication {
    name = "record.sh";
    runtimeInputs = with pkgs; [
      slop
      ffmpeg
      libnotify
    ];
    text = (builtins.readFile ./record.sh);
  };
in
{
  xsession = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      config = {
        bars = [ ];
        gaps = {
          inner = 5;
        };
        window.border = 5;
        floating.border = 5;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = lib.mkOptionDefault {
          "Print" = "${exec} flameshot gui";
          "${mod}+Return" = "${exec} ${term}";
          "${sup}+Return" = "${exec} ${selecterm}/bin/select-term.sh";
          "${mod}+d" = "focus child";
          "${mod}+o" = "open";
          "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
          "${sup}+Right" = "resize grow width 5 px or 5 ppt";
          "${sup}+Down" = "resize grow height 5 px or 5 ppt";
          "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
          "${sup}+space" = "${exec} ~/.config/rofi/roficomma.sh -lines 10 -width 40";
          "${mod}+e" = "${exec} ${pkgs.rofimoji}/bin/rofimoji";
          "${mod}+w" = "${exec} echo This line is just here to unbind mod+w";
          "${mod}+r" = "${exec} ${record}/bin/record.sh";
          "${mod}+p" = "${exec} ${pkgs.nur.repos.reedrw.bitwarden-rofi-patched}/bin/bwmenu --auto-lock 0";
          "${mod}+Shift+s" = "sticky toggle";
          "XF86MonBrightnessUp" = "${exec} xbacklight -inc 10";
          "XF86MonBrightnessDown" = "${exec} xbacklight -dec 10";
          "Ctrl+Down" = "${exec} ${pkgs.mpc_cli}/bin/mpc toggle";
          "Ctrl+Left" = "${exec} ${pkgs.mpc_cli}/bin/mpc prev";
          "Ctrl+Right" = "${exec} ${pkgs.mpc_cli}/bin/mpc next";
          "XF86AudioPause" = "${exec} ${pkgs.mpc_cli}/bin/mpc toggle";
          "XF86AudioPlay" = "${exec} ${pkgs.mpc_cli}/bin/mpc toggle";
          "XF86AudioPrev" = "${exec} ${pkgs.mpc_cli}/bin/mpc prev";
          "XF86AudioNext" = "${exec} ${pkgs.mpc_cli}/bin/mpc next";
        };
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
            command = "border none";
            criteria = {
              class = "firefox";
            };
          }
          {
            command = "border none";
            criteria = {
              class = "mpv";
            };
          }
          {
            command = "border none";
            criteria = {
              class = "Alacritty";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "Alacritty";
              title = "float";
            };
          }
        ];
        startup = []
        ++
        builtins.map ( command:
            {
              command = command;
              always = true;
              notification = false;
            }
          ) alwaysRun
        ++
          builtins.map ( command:
            {
              command = command;
              notification = false;
            }
          ) run;
      };
    };
  };
  services = {
    flameshot.enable = true;
  };
  home.file.".background-image".source = ./wallpaper.jpg;

  xdg.configFile = {
    "i3/workspace-1.json".source = ./workspace-1.json;
    "i3/workspace-2.json".source = ./workspace-2.json;
    "i3/workspace-4.json".source = ./workspace-4.json;
  };

}
