{ config, lib, pkgs, ... }:
let
  term = "alacritty";

  mod = "Mod1";
  sup = "Mod4";
  run = "exec --no-startup-id";

  selecterm = pkgs.writeShellScript "select-term.sh" ''
    read -r X Y W H < <(${pkgs.slop}/bin/slop -f "%x %y %w %h" -b 1 -t 0 -q)
    # Width and Height in px need to be converted to columns/rows
    # To get these magic values, make a fullscreen st, and divide your screen width by ''${tput cols}, height by ''${tput lines}
    (( W /= 5 ))
    (( H /= 11 ))
    # Arithmetic operations to correct for border
    alacritty -t float -o window.dimensions.columns=$((''${W}-5)) window.dimensions.lines=$((''${H}-3)) window.position.x=''${X} window.position.y=''${Y}
  '';

  record = pkgs.writeShellScript "record.sh" ''
    startrec(){
      set $(${pkgs.slop}/bin/slop -q -o -f '%x %y %w %h')

      ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error \
        -show_region 1 \
        -s ''${3}x''${4} \
        -framerate 60 \
        -f x11grab \
        -i :0.0+''${1},''${2} \
        -crf 16 \
        -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
        ~/"record-$(date '+%a %b %d - %l:%M %p')".mp4
    }

    pid="$(pgrep -f x11grab)" && \
      ( kill -SIGINT "$pid"; sleep .3; ${pkgs.libnotify}/bin/notify-send "recording stopped" ) || \
      startrec

  '';

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
          inner = 10;
        };
        window.border = 5;
        floating.border = 5;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = lib.mkOptionDefault {
          "Print" = "${run} flameshot gui";
          "${mod}+Return" = "${run} ${term}";
          "${sup}+Return" = "${run} ${selecterm}";
          "${mod}+d" = "focus child";
          "${mod}+o" = "open";
          "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
          "${sup}+Right" = "resize grow width 5 px or 5 ppt";
          "${sup}+Down" = "resize grow height 5 px or 5 ppt";
          "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
          "${sup}+space" = "${run} rofi -show run -lines 10 -width 40";
          "${mod}+e" = "${run} ${pkgs.rofimoji}/bin/rofimoji --insert-with-clipboard";
          "${mod}+r" = "${run} ${record}";
          "${mod}+p" = "${run} ${pkgs.nur.repos.reedrw.bitwarden-rofi-patched}/bin/bwmenu --auto-lock 0";
          "Ctrl+Down" = "${run} ${pkgs.mpc_cli}/bin/mpc toggle";
          "Ctrl+Left" = "${run} ${pkgs.mpc_cli}/bin/mpc prev";
          "Ctrl+Right" = "${run} ${pkgs.mpc_cli}/bin/mpc next";
        };
        colors = with config.lib.base16.theme; {
          focused = {
            border = "#${base07-hex}";
            childBorder = "#${base07-hex}";
            background = "#${base07-hex}";
            text = "#${base07-hex}";
            indicator = "#${base07-hex}";
          };
          focusedInactive = {
            border = "#${base03-hex}";
            childBorder = "#${base03-hex}";
            background = "#${base03-hex}";
            text = "#${base03-hex}";
            indicator = "#${base03-hex}";
          };
          unfocused = {
            border = "#${base03-hex}";
            childBorder = "#${base03-hex}";
            background = "#${base03-hex}";
            text = "#${base03-hex}";
            indicator = "#${base03-hex}";
          };
          urgent = {
            border = "#${base03-hex}";
            childBorder = "#${base03-hex}";
            background = "#${base00-hex}";
            text = "#${base05-hex}";
            indicator = "#${base00-hex}";
          };
        };
        window.commands = [
          {
            command = "border none";
            criteria = {
              class = "Firefox";
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
        startup = [
          {
            command = "systemctl --user restart picom";
            always = true;
            notification = false;
          }
          {
            command = "systemctl --user restart polybar";
            always = true;
            notification = false;
          }
          {
            command = "xset r rate 250 50";
            always = true;
            notification = false;
          }
          {
            command = "xrdb -load ~/.Xresources";
            notification = false;
          }
          {
            command = "xinput --disable $(xinput | grep -o 'TouchPad.*id=[0-9]*' | cut -d '=' -f 2)";
            notification = false;
          }
          {
            command = "${pkgs.feh}/bin/feh --bg-fill ~/.background-image";
            always = true;
            notification = false;
          }
          {
            command = "i3-msg workspace number 1";
            notification = false;
          }
        ];
      };
    };
  };
  services = {
    flameshot.enable = true;
  };
  home.file.".background-image".source = ./wallpaper.jpg;
}
