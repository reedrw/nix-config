{ config, lib, pkgs, ... }:

{
  services.dunst = {
    enable = true;
    settings = with config.lib.base16.theme; {
      global = {
        monitor = 0;
        geometry = "250x50-50+55";
        shrink = "yes";
        padding = 16;
        horizontal_padding = 16;
        frame_width = 0;
        frame_color = "${base00-hex}";
        separator_color = "frame";
        font = "scientifica 8";
        line_height = 4;
        markup = "full";
        format = ''%s\n%b'';
        alignment = "left";
        word_wrap = "yes";
        ignore_newline = "no";
        show_indicators = "no";
        startup_notification = false;
        hide_duplicate_count = true;
      };
      urgency_low = {
        background = "#${base00-hex}";
        forefround = "#${base05-hex}";
        timeout = 4;
      };
      urgency_normal = {
        background = "#${base00-hex}";
        forefround = "#${base05-hex}";
        timeout = 4;
      };
      urgency_critical = {
        background = "#${base00-hex}";
        forefrond = "#${base05-hex}";
        frame_color = "#${base08-hex}";
        timeout = 4;
      };
    };
  };
}
