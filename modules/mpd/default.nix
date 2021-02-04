{ config, lib, pkgs, ... }:

{
  services.mpd = {
    enable = true;
    extraConfig = ''
      audio_output {
        type            "pulse"
        name            "pulse audio"
      }
      audio_output {
        type                    "fifo"
        name                    "my_fifo"
        path                    "/tmp/mpd.fifo"
        format                  "44100:16:2"
      }
    '';
  };

  programs.ncmpcpp = {
    enable = true;
    package = pkgs.ncmpcpp.override {
      visualizerSupport = true;
    };
    settings = {
      visualizer_fifo_path = "/tmp/mpd.fifo";
      visualizer_output_name = "fifo";
      visualizer_sync_interval = "30";
      visualizer_in_stereo = "yes";
      visualizer_look = "xx";
      song_columns_list_format = "(6f)[blue]{l} (25)[red]{a} (40)[green]{t|f} (30)[yellow]{b}";
      now_playing_prefix = "$b$5»$7»$1» ";
      now_playing_suffix = "$/b";
      playlist_display_mode = ''"columns" (classic/columns)'';
      autocenter_mode = "yes";
      centered_cursor = "yes";
      song_status_format = "$2%a $1• $3%t $1• $4%b {(Disc %d) }$1• $5%y$1";
      progressbar_look = "─╼·";
      titles_visibility = "no";
      browser_playlist_prefix = "$2plist »$9 ";
      browser_display_mode = ''"columns" (classic/columns)'';
      discard_colors_if_item_is_selected = "yes";
      header_window_color = "white";
      volume_color = "cyan";
      state_line_color = "green";
      state_flags_color = "yellow";
      main_window_color = "white";
      color1 = "default";
      color2 = "green";
      current_item_prefix = "$(red)$r";
      current_item_suffix = "$/r$(end)";
      progressbar_color = "yellow";
      statusbar_color = "white";
      current_item_inactive_column_prefix = "$(red)$r";
      current_item_inactive_column_suffix = "$/r$(end)";
      lyrics_fetchers = "genius, metrolyrics, justsomelyrics, jahlyrics, plyrics, tekstowo, internet";
      song_window_title_format = "{%a > }{%t}{ [%b{ Disc %d}]}|{%f}";
      search_engine_display_mode = ''"columns" (classic/columns)'';
      follow_now_playing_lyrics = "yes";
      allow_for_physical_item_deletion = "yes";
    };
  };

}
