{ config, ... }:

{
  services.dunst = {
    enable = true;
    settings = with config.lib.stylix.colors; {
      global = {
        monitor = 0;
        width = "(0, 250)";
        height = "(0, 50)";
        offset = "50x55";
        shrink = "yes";
        padding = 16;
        horizontal_padding = 16;
        frame_width = 0;
        frame_color = "#${base00}";
        separator_color = "frame";
        font = "FantasqueSansM Nerd Font Bold 10";
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
        background = "#${base00}";
        forefround = "#${base05}";
        timeout = 4;
      };
      urgency_normal = {
        background = "#${base00}";
        forefround = "#${base05}";
        timeout = 4;
      };
      urgency_critical = {
        background = "#${base00}";
        forefrond = "#${base05}";
        frame_color = "#${base08}";
        timeout = 4;
      };
    };
  };
}
