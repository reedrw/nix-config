{ pkgs, ... }:
{
  stylix.targets.kitty = {
    enable = true;
    variant256Colors = true;
  };

  home.sessionVariables.TERMINAL = "kitty";

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
    settings = let
      family = "FantasqueSansM Nerd Font";
    in {
      font_size = 10;
      font_family = "${family} Bold";
      bold_font = ''family="${family}" style="Bold"'';
      italic_font = "${family} Italic";
      bold_italic_font = "${family} Bold Italic";
      window_padding_width = 10;

      hide_window_decorations = true;

      enable_audio_bell = false;
      cursor_shape = "beam";
      confirm_os_window_close = 0;

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
