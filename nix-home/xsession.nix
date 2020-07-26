{ config, lib, pkgs, ... }:

let

  term = "urxvtc";

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

      ${pkgs.feh}/bin/feh --bg-fill ~/.config/nixpkgs/nix-home/wallpaper.jpg

      systemctl restart --user polybar

      i3-msg workspace number 1

      pidof urxvtd || urxvtd -q -o -f
    '';
  };
in
{
  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
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
          "${mod}+d" = "focus child";
          "${mod}+o" = "open";
          "${sup}+Left" = "resize shrink width 5 px or 5 ppt";
          "${sup}+Right" = "resize grow width 5 px or 5 ppt";
          "${sup}+Down" = "resize grow height 5 px or 5 ppt";
          "${sup}+Up" = "resize shrink height 5 px or 5 ppt";
          "${sup}+space" = "exec --no-startup-id rofi -show run -lines 10 -width 40";
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
        for_window [class="URxvt"] border none
        exec --no-startup-id "${autorun}"
        exec --no-startup-id sh -c '[[ -f ~/.autostart.sh ]] && ~/.autostart.sh'
      '';
    };
  };
}

