{ config, lib, pkgs, ... }:

let

  term = "st";

  mod = "Mod1";
  sup = "Mod4";

  # This is will  run when i3 starts
  autorun = pkgs.writeTextFile {
    name = "autorun.sh";
    executable = true;
    text = ''
      #!${pkgs.stdenv.shell}

      touchpad="$(xinput | grep -o 'TouchPad.*id=[0-9]*' | cut -d '=' -f 2)"

      xset r rate 250 50
      xrdb -load ~/.Xresources
      xinput --disable $touchpad

      ${pkgs.feh}/bin/feh --bg-fill ~/.config/nixpkgs/nix-home/xsession/wallpaper.jpg

      systemctl restart --user polybar

      i3-msg workspace number 1
    '';
  };

  selecterm = pkgs.writeTextFile {
    name = "select-term.sh";
    executable = true;
    text = ''
      #!${pkgs.stdenv.shell}

      read -r X Y W H < <(${pkgs.slop}/bin/slop -f "%x %y %w %h" -b 1 -t 0 -q)
      # Width and Height in px need to be converted to columns/rows
      # To get these magic values, make a fullscreen st, and divide your screen width by ''${tput cols}, height by ''${tput lines}
      (( W /= 5 ))
      (( H /= 11 ))
      # Arithmetic operations to correct for border
      g=$((''${W}-5))x$((''${H}-3))+''${X}+''${Y}
      st -t float -g $g
    '';
  };

  record = pkgs.writeTextFile {
    name = "record.sh";
    executable = true;
    text = ''
      #!${pkgs.stdenv.shell}

      startrec(){
        set $(${pkgs.slop}/bin/slop -q -o -f '%x %y %w %h')

        ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error \
          -show_region 1 \
          -s ''${3}x''${4} \
          -r 60 \
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
  };

in
{
  xsession = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      config = {
        bars = [];
        gaps = {
          inner = 10;
        };
        window.border = 5;
        floating.border = 5;
        modifier = "${mod}";
        terminal = "${term}";
        keybindings = lib.mkOptionDefault {
          "Print" = "exec --no-startup-id flameshot gui";
          "${mod}+Return" = "exec --no-startup-id ${term}";
          "${sup}+Return" = "exec --no-startup-id ${selecterm}";
          "${mod}+d" = "focus child";
          "${mod}+o" = "open";
          "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
          "${sup}+Right" = "resize grow width 5 px or 5 ppt";
          "${sup}+Down" = "resize grow height 5 px or 5 ppt";
          "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
          "${sup}+space" = "exec --no-startup-id rofi -show run -lines 10 -width 40";
          "${mod}+r" = "exec --no-startup-id ${record}";
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
            childBorder = "#${base00-hex}";
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
            border = "#${base00-hex}";
            childBorder = "#${base00-hex}";
            background = "#${base00-hex}";
            text = "#${base05-hex}";
            indicator = "#${base00-hex}";
          };
        };
      };
      extraConfig = ''
        for_window [class="Firefox"] border none
        for_window [class="mpv"] border none
        for_window [class="TelegramDesktop"] border none
        for_window [class="st-256color"] border none
        for_window [class="st-256color" title="float"] floating enable
        exec --no-startup-id "${autorun}"
      '';
    };
  };
  services.flameshot = {
      enable = true;
  };
}

