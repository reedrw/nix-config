{ config,  ... }:

with config.lib.stylix.colors;
{
  programs.rofi.theme = builtins.toFile "theme.rasi" ''
    configuration {
      drun {
        display-name: "";
      }

      run {
        display-name: "";
      }

      window {
        display-name: "";
      }

      ssh {
        display-name: "";
      }

      timeout {
        delay: 10;
        action: "kb-cancel";
      }
    }

    * {
      border: 0;
      margin: 0;
      padding: 0;
      spacing: 0;

      bg: #${base00};
      bg-alt: #${base01};
      fg: #${base05};
      fg-alt: #${base04};

      background-color: @bg;
      text-color: @fg;
    }

    window {
      transparency: "real";
    }

    mainbox {
      children: [inputbar, listview];
    }

    inputbar {
      background-color: @bg-alt;
      children: [prompt, entry];
    }

    entry {
      background-color: inherit;
      padding: 12px 3px;
    }

    prompt {
      background-color: inherit;
      padding: 12px;
    }

    listview {
      lines: 8;
    }

    element {
      children: [element-text];
    }

    element-icon {
      padding: 10px 10px;
    }

    element-text {
      padding: 10px 10px;
      text-color: @fg-alt;
    }

    element-text selected {
      text-color: @fg;
    }
  '';
}
