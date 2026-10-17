{ pkgs, config, lib, osConfig, ... }:
let
  inherit (osConfig.custom.display) dp;
in

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    font = "FantasqueSansM Nerd Font Bold ${toString (dp 10)}";
    plugins = [ pkgs.rofi-emoji ];
    extraConfig = {
      # nerd-font glyphs replace the mode labels in the prompt
      display-run = ""; # nf-fa-search
      display-emoji = "󰱰"; # nf-md-emoticon_excited
    };
    theme = builtins.toFile "theme.rasi" (
      with config.lib.stylix.colors;
      ''
        * {
          margin: 0;
          padding: 0;
          spacing: 0;

          bg:     #${base00};
          bg-alt: #${base01};
          fg:     #${base05};
          fg-alt: #${base04};

          background-color: transparent;
          text-color:       @fg;
        }

        /* bg + radius live on window: children paint over the corners of
           anything rounded below them, so the box is drawn here and
           mainbox/listview stay transparent (matches the wofi look). */
        window {
          background-color: @bg;
          border-radius: ${toString (dp 12)}px;
          location: center;
          width: 50%;
        }
        mainbox   { children: [inputbar, listview]; }
        inputbar  {
          background-color: @bg-alt;
          border-radius: ${toString (dp 12)}px ${toString (dp 12)}px 0 0;
          children: [prompt, entry];
        }
        entry     { background-color: inherit; padding: ${toString (dp 14)}px; }
        prompt    { background-color: inherit; padding: ${toString (dp 14)}px; }
        listview  {
          lines: 8;
          scrollbar: false;
          fixed-height: true;
        }
        element   { children: [element-text]; }
        element-text {
          padding: ${toString (dp 11)}px;
          text-color: @fg-alt;
        }
        element-text selected { text-color: @fg; }
      ''
    );
  };

  lib.scripts.rofi-comma = pkgs.writeNixShellScript "rofi-comma"
    <| builtins.readFile ./rofi-comma.sh;

  # rofi-emoji is a mode plugin rather than a standalone picker; wtype inserts
  # the chosen emoji into the focused window, wl-clipboard is the fallback
  # that insert mode copies through
  lib.scripts.rofi-emoji = pkgs.writeShellApplication {
    name = "rofi-emoji";
    runtimeInputs = [
      pkgs.wl-clipboard
      pkgs.wtype
    ];
    text = ''
      exec ${lib.getExe config.programs.rofi.finalPackage} -modi emoji -show emoji "$@"
    '';
  };

  wayland.windowManager.sway.extraConfig = ''
    layer_effects "rofi" {
      shadows enable;
      corner_radius ${toString (dp 12)};
    }
  '';

  custom.persistence.files = [
    ".cache/rofi-2.sshcache"
    ".cache/rofi-3.runcache"
    ".cache/rofi-4.runcache"
    ".cache/rofi-entry-history.txt"
    ".cache/rofi3.druncache"
  ];
}
