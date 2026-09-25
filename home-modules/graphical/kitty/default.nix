{ pkgs, config, osConfig, ... }:
let
  inherit (osConfig.custom.display) dp;

  # ExecStartPre guard: refuses to start (exit 1) while a live kitty
  # single-instance primary exists, because `kitty --single-instance` would
  # then JOIN it — opening a stray visible window running the server's sleep
  # child — and the client would exit 0, leaving the service dead.
  #
  # Single-instance sockets live at /tmp/kitty-<pid>; the pid in the name is
  # the primary's pid, so liveness is checked via /proc/<pid>/comm. A crashed
  # kitty leaves a stale socket whose pid is gone (or reused by a non-kitty
  # process), which the comm check ignores — the service then legitimately
  # takes over as primary.
  precheck = pkgs.writeShellScript "kitty-server-precheck"
    (builtins.readFile ./kitty-server-precheck.sh);
in
{
  stylix.targets.kitty = {
    enable = true;
    variant256Colors = true;
  };

  home.sessionVariables.TERMINAL = "kitty";

  # Hidden kitty single-instance server: alt+enter windows join it (~3ms
  # instead of an ~85ms cold start) and the server survives closing the last
  # visible window because its hidden sleep child never exits. Runs as a
  # systemd user service (not compositor autostart) for crash recovery: when
  # it dies, on-failure retries take over again. It must never be *restarted*
  # while kitty windows are open — restarting kills every one of them.
  systemd.user.services."kitty-server" = {
    Unit = {
      Description = "kitty single-instance server (fast window opens)";
      After = [ "graphical.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      # Skip (fail) while a live primary exists. Login-time starts fail
      # anyway (no WAYLAND_DISPLAY before the compositor); the on-failure
      # retry then starts the server once it is up.
      ExecStartPre = "${precheck}";
      ExecStart =
        "${config.programs.kitty.package}/bin/kitty --start-as=hidden -e sh -c 'exec sleep infinity'";
      Restart = "on-failure";
      RestartSec = 5;
      Type = "simple";
    };
  };

  programs.kitty = {
    enable = true;
    # --single-instance joins the hidden server instance started by the
    # kitty-server user service, making window opens ~3ms instead of an
    # ~85ms cold start. The server survives closing the last visible window
    # because its hidden window never closes. Trade-off: all kitty windows
    # share one process, so a kitty crash takes them all down.
    # -e is kept for xterm/i3-sensible-terminal compatibility; kitty treats
    # remaining positional args as the command to run either way.
    package = pkgs.wrapPackage pkgs.kitty (kitty: ''
      #!${pkgs.stdenv.shell}
      if [[ "$1" == "-e" ]]; then
        shift
      fi
      exec ${kitty} --single-instance "$@"
    '');
    shellIntegration.mode = null;
    settings = let
      # Mono variant: identical latin glyphs to the plain "Nerd Font" family,
      # but its private-use icon glyphs are single-cell by design (the plain
      # variant draws them double-width, which oversizes statusline/prompt
      # icons).
      family = "FantasqueSansM Nerd Font Mono";
    in {
      font_size = dp 10;
      font_family = ''family="${family}" style="Regular"'';
      bold_font = ''family="${family}" style="Bold"'';
      italic_font = "${family} Italic";
      bold_italic_font = "${family} Bold Italic";
      window_padding_width = dp 10;

      hide_window_decorations = true;

      enable_audio_bell = false;
      cursor_shape = "beam";
      confirm_os_window_close = 0;

      # Default window command. `shell` (unlike startup_session) also applies
      # to windows joined to an already-running --single-instance primary.
      shell = "tmux";
    };
    keybindings = {
      "shift+return" = "send_text all \\e[13;2u";
    };
    extraConfig = ''
      modify_font underline_position 2
    ''
    + (
      if config.stylix.polarity == "dark"
      then ''
        text_composition_strategy platform
      '' else ''
        text_composition_strategy 1.7 0
      ''
    );
  };
}
