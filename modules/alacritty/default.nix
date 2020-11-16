{ config, lib, pkgs, ... }:
{

  programs.alacritty = {
    enable = true;
  };

  xdg.configFile."alacritty/alacritty.yml".text = ''

    ################

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

    ################

    mouse_bindings:
    - { mouse: Middle, action: PasteSelection }


    ################
    ${builtins.readFile "${config.lib.base16.base16template "alacritty"}" }
  '';

}
