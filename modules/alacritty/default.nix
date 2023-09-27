{ inputs, config, pkgs, ... }:
let
  tmuxconf = builtins.toFile "tmuxconf" ''
    set -g status off
    set -g destroy-unattached on
    set -g mouse on
    set -g default-terminal 'tmux-256color'
    set -ga terminal-overrides ',alacritty:RGB'
    set -s escape-time 0
    set -g history-limit 10000
  '';
in
{

  home.packages = [ pkgs.scientifica ]; # font

  programs.alacritty = {
    enable = true;
    # select-term script broken by bug introduced at commit 0e418bc2f761617455cc58aaabc375055dfe4284
    # https://github.com/alacritty/alacritty/issues/6884
    package = with pkgs; versionConditionalOverride "0.13" alacritty (
      alacritty.overrideAttrs (_: rec {
        src = inputs.alacritty;

        cargoDeps = rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
        };
      })
    );
    settings = {
      live_config_reload = true;
      # copied from
      # https://github.com/aarowill/base16-alacritty/blob/master/templates/default.mustache
      colors = with config.colorScheme.colors; let
        black   = "0x${base00}";
        blue    = "0x${base0D}";
        cyan    = "0x${base0C}";
        green   = "0x${base0B}";
        grey    = "0x${base03}";
        magenta = "0x${base0E}";
        red     = "0x${base08}";
        white   = "0x${base05}";
        yellow  = "0x${base0A}";
      in {
        primary = {
          background = black;
          foreground = white;
        };
        cursor = {
          text = black;
          cursor = white;
        };
        normal = {
          inherit black blue cyan green magenta red white yellow;
        };
        bright = {
          black = grey;
          inherit blue cyan green magenta red white yellow;
        };
        draw_bold_text_with_bright_colors = false;
      };
      cursor.style = "Beam";
      font = {
        size = 8;
        normal = {
          family = "scientifica";
          style = "Medium";
        };
        bold = {
          family = "scientifica";
          style = "Bold";
        };
        italic = {
          family = "scientifica";
          style = "Italic";
        };
        bold_italic = {
          family = "scientifica";
          style = "Bold";
        };
      };
      window = {
        dynamic_padding = true;
        padding = {
          x = 15;
          y = 15;
        };
      };
      shell = with pkgs; {
        program = "${binPath tmux}";
        args = [
          "-f"
          "${tmuxconf}"
        ];
      };
    };
  };
}
