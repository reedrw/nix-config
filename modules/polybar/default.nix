{ config, lib, pkgs, ... }:

{
  services.polybar = {
    enable = true;
    package = pkgs.polybarFull;
    config = with config.lib.base16.theme; {
      "bar/main" = {
        background = "#${base00-hex}";
        foreground = "#${base05-hex}";
        modules-left = "i3";
        modules-right = "mpd battery date";
        border-left-size = 1;
        border-left-color = "#${base00-hex}";
        border-right-size = 1;
        border-right-color = "#${base00-hex}";
        border-top-size = 2;
        border-top-color = "#${base00-hex}";
        border-bottom-size = 2;
        border-bottom-color = "#${base00-hex}";
        font-0 = "lemon:pixelsize=10;1";
      };
      "module/battery" = {
        type = "internal/battery";
      };
      "module/date" =
        let
          calnotify = pkgs.writeShellScript "calnotify.sh" ''
            day="$(${pkgs.coreutils}/bin/date +'%-d ' | ${pkgs.gnused}/bin/sed 's/\b[0-9]\b/ &/g')"
            cal="$(${pkgs.utillinux}/bin/cal | ${pkgs.gnused}/bin/sed -e 's/^/ /g' -e 's/$/ /g' -e "s/$day/\<span color=\'#${base0B-hex}\'\>\<b\>$day\<\/b\>\<\/span\>/" -e '1d')"
            top="$(${pkgs.utillinux}/bin/cal | ${pkgs.gnused}/bin/sed '1!d')"

            ${pkgs.libnotify}/bin/notify-send "$top" "$cal"
          '';
        in
        {
          type = "internal/date";
          date = "%I:%M %p    %a %b %d";
          label = "%{A1:${calnotify}:}%date%%{A}";
          format = "<label>";
          label-padding = 5;
        };
      "module/i3" = {
        type = "internal/i3";
        label-unfocused-foreground = "#${base03-hex}";
        label-urgent-foreground = "#${base09-hex}";
        label-unfocused-padding = 1;
        label-focused-padding = 1;
        label-urgent-padding = 1;
      };
      "module/mpd" = {
        type = "internal/mpd";
        label-song = "%{A1:${pkgs.mpc_cli}/bin/mpc toggle:}%artist% - %title%%{A}";
        icon-play = " (paused)";
        icon-play-foreground = "#${base03-hex}";
        icon-pause = "";
        format-online = "<label-song><toggle>";
      };
    };
    script = ''
      polybar main &
    '';
  };

}
