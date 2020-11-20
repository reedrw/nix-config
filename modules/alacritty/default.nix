{ config, lib, pkgs, ... }:
let
  tmuxconf = builtins.toFile "tmuxconf" ''
    set -g status off
    set -g destroy-unattached on
    set -g mouse on
    set -g default-terminal 'tmux-256color'
    set -ga terminal-overrides ',alacritty:RGB'
  '';
in
{

  programs.alacritty.enable = true;

  xdg.configFile."alacritty/alacritty.yml".text = ''
    import:
      - ${config.lib.base16.base16template "alacritty"}

    live_config_reload: true

    cursor:
      style: Underline

    font:
      normal:
        family: scientifica
        style: Medium

      bold:
        family: scientifica
        style: Bold

      italic:
        family: scientifica
        style: Medium

      bold_italic:
        family: scientifica
        style: Bold

      size: 8

    window:
      dynamic_padding: true
      padding:
        x: 15
        y: 15

    shell:
      program: ${pkgs.tmuxnew}/bin/tmux
      args:
        - -f
        - ${tmuxconf}
  '';

}
