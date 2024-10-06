{ pkgs, lib, ... }:
let
  sources = import ./nix/sources.nix { };
  # use https://github.com/ncmpcpp/ncmpcpp master until new release
  # this fixes the genius lyric fetcher
  ncmpcpp = pkgs.versionConditionalOverride "0.9.2" pkgs.ncmpcpp (pkgs.ncmpcpp.overrideAttrs
    (old: {
      src = sources.ncmpcpp;
      version = lib.shortenRev sources.ncmpcpp.rev;

      nativeBuildInputs = with pkgs; [
        autoconf
        automake
        libtool
        autoreconfHook
      ] ++ old.nativeBuildInputs;

      # preConfigure = ''
      #   ./autogen.sh
      # '';
    })
  );
in
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

  services.mpd-mpris.enable = true;

  services.playerctld.enable = true;
  systemd.user.services.playerctld = {
    Unit = {
      After = [ "graphical.target" ];
    };
    Service = {
      RestartSec = 5;
    };
  };

  programs.ncmpcpp = {
    enable = true;
    package = ncmpcpp.override {
      visualizerSupport = true;
    };
    settings = {
      visualizer_data_source = "/tmp/mpd.fifo";
      visualizer_output_name = "fifo";
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
