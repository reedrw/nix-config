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

  run = [
    "i3-msg workspace 1"
  ];

  scripts = import ./scripts { inherit pkgs; };
  sources = import ./nix/sources.nix { };

in
{
  xsession = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps.overrideAttrs (
        old: rec {
          version = sources.i3-gaps.rev;
          src = sources.i3-gaps;
        }
      );
      config = {
        bars = [ ];
        gaps = {
          inner = 5;
        };
        window.border = 5;
        floating.border = 5;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = with scripts; lib.mkOptionDefault (
          {
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
            "${mod}+r" = "${exec} ${record}/bin/record.sh";
            "${mod}+p" = "${exec} ${bwmenu-patched}/bin/bwmenu";
            "${mod}+Shift+s" = "sticky toggle";
            "XF86MonBrightnessUp" = "${exec} xbacklight -inc 10";
            "XF86MonBrightnessDown" = "${exec} xbacklight -dec 10";
            "Ctrl+Down" = "${exec} ${pkgs.playerctl}/bin/playerctl play-pause";
            "Ctrl+Left" = "${exec} ${pkgs.playerctl}/bin/playerctl previous";
            "Ctrl+Right" = "${exec} ${pkgs.playerctl}/bin/playerctl next";
            "XF86AudioPause" = "${exec} ${pkgs.playerctl}/bin/platerctl play-pause";
            "XF86AudioPlay" = "${exec} ${pkgs.playerctl}/bin/platerctl play-pause";
            "XF86AudioPrev" = "${exec} ${pkgs.playerctl}/bin/platerctl previous";
            "XF86AudioNext" = "${exec} ${pkgs.playerctl}/bin/platerctl next";
          } // lib.attrsets.mapAttrs' (x: y: lib.attrsets.nameValuePair
            ("${mod}+ctrl+${x}") ("${exec} ${load-layouts}/bin/load-layouts.sh ${x}")
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
            command = "border none";
            criteria = {
              class = "TelegramDesktop";
            };
          }
          {
            command = "border none";
            criteria = {
              class = "Element";
            };
          }
          {
            command = "border none";
            criteria = {
              class = "discord";
            };
          }
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
  home.file.".background-image".source = ./wallpaper.png;

  xdg.configFile = {
    "i3/workspace-1.json".source = ./workspace-1.json;
    "i3/workspace-2.json".source = ./workspace-2.json;
    "i3/workspace-4.json".source = ./workspace-4.json;
  };

  systemd.user.services.clipboard-clean = {
    Unit = {
      After = [ "graphical.target" ];
      Description = "Clean URLS on clipboard using ClearURL rules.";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = "${scripts.clipboard-clean}/bin/clipboard-clean";
      Restart = "on-failure";
      Type = "simple";
    };
  };
}
