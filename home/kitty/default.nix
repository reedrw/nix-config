{ config, pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    # The -e flag doesn't work when a startup_session is specified.
    # This disgusting hack is needed to keep backwards compatibility with
    # xterm. i3-sensible-terminal uses the -e flag to execute a command.
    package = pkgs.wrapPackage pkgs.kitty (kitty: ''
      #!${pkgs.stdenv.shell}
      if [[ "\$1" == "-e" ]]; then
        shift
        exec ${kitty} --session=none "\$@"
      else
        exec ${kitty} "\$@"
      fi
    '');
    # shellIntegration.enableZshIntegration = true;
    settings = with config.lib.stylix.scheme; let
      family = "FantasqueSansM Nerd Font";

      black   = "#${base00}";
      blue    = "#${base0D}";
      cyan    = "#${base0C}";
      green   = "#${base0B}";
      grey    = "#${base03}";
      magenta = "#${base0E}";
      red     = "#${base08}";
      white   = "#${base05}";
      yellow  = "#${base0A}";
    in {
      font_size = 10;
      font_family = "${family} Bold";
      bold_font = "${family} Bold";
      italic_font = "${family} Italic";
      bold_italic_font = "${family} Bold Italic";
      window_padding_width = 10;

      enable_audio_bell = false;
      cursor_shape = "beam";
      confirm_os_window_close = 0;

      background = black;
      foreground = white;

      selection_background = grey;

      color0 = black;
      color1 = red;
      color2 = green;
      color3 = yellow;
      color4 = blue;
      color5 = magenta;
      color6 = cyan;
      color7 = white;
      color8 = grey;
      color9 = red;
      color10 = green;
      color11 = yellow;
      color12 = blue;
      color13 = magenta;
      color14 = cyan;
      color15 = white;

      startup_session = "${pkgs.writeText "launch.conf" ''
        launch tmux
      ''}";
    };
    extraConfig = ''
      modify_font underline_position 2
      text_composition_strategy legacy
    '';
  };
}
