{ pkgs, config, ... }:

{
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      lines = 8;
      font = "FantasqueSansM Nerd Font Bold 10";
      hide_scroll = true;
      no_actions = true;
      insensitive = true;
    };
    style = with config.lib.stylix.colors; ''
      * {
        font-family: "FantasqueSansMNerdFont", "Kochi Gothic";
        font-size: 10pt;
        font-weight: bold;
        border: none;
        outline: none;
      }

      #window {
        background-color: transparent;
      }

      #outer-box {
        background-color: #${base00};
        border-radius: 10px;
        padding: 0;
        margin: 0;
      }

      #input {
        background-color: #${base01};
        color: #${base05};
        padding: 12px;
        border-radius: 10px 10px 0 0;
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
        padding: 10px;
      }

      #text {
        color: #${base04};
        padding: 10px;
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
