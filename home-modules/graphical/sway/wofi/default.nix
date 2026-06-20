{ pkgs, config, osConfig, ... }:
let
  inherit (osConfig.custom.display) dp;
in
{
  programs.wofi = {
    enable = true;
    settings = {
      width = "50%";
      lines = 8;
      font = "FantasqueSansM Nerd Font Bold ${toString (dp 10)}";
      hide_scroll = true;
      no_actions = true;
      insensitive = true;
    };
    style = with config.lib.stylix.colors; ''
      * {
        font-family: "FantasqueSansMNerdFont", "Kochi Gothic";
        font-size: ${toString (dp 10)}pt;
        font-weight: bold;
        border: none;
        outline: none;
      }

      #window {
        background-color: transparent;
      }

      #outer-box {
        background-color: #${base00};
        border-radius: 0.75em;
        box-shadow: 0 0.15em 0.75em rgba(0, 0, 0, 0.6);
        padding: 0;
        margin: 1.5em;
      }

      entry,
      entry:focus,
      #input,
      #input:focus {
        background-color: #${base01};
        color: #${base05};
        padding: 0.9em;
        border-radius: 0.75em 0.75em 0 0;
        box-shadow: none;
        border: none;
        border-color: transparent;
        outline: none;
        outline-color: transparent;
      }

      #scroll {
        background-color: transparent;
        margin: 0;
        padding: 0;
      }

      #inner-box {
        background-color: transparent;
        margin: 0;
        padding: 0;
      }

      #entry {
        background-color: transparent;
        padding: 0;
      }

      #entry:selected {
        background-color: transparent;
      }

      #img {
        padding: 0.75em;
      }

      #text {
        color: #${base04};
        padding: 0.75em;
      }

      #text:selected {
        color: #${base05};
      }
    '';
  };

  lib.scripts.wofi-comma = pkgs.writeNixShellScript "wofi-comma"
    <| builtins.readFile ./wofi-comma.sh;

  home.packages = [ pkgs.wofi-emoji ];

  custom.persistence.files = [
    ".cache/wofi-run"
    ".cache/wofi-dmenu"
    ".cache/wofi-drun"
  ];
}
