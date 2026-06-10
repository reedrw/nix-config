{ pkgs, config, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    font = "FantasqueSansM Nerd Font Bold 10";
    theme = builtins.toFile "theme.rasi" (
      with config.lib.stylix.colors;
      ''
        * {
          border: 0;
          margin: 0;
          padding: 0;
          spacing: 0;

          bg:     #${base00};
          bg-alt: #${base01};
          fg:     #${base05};
          fg-alt: #${base04};

          background-color: @bg;
          text-color:       @fg;
        }

        window    { transparancy: "real"; }
        mainbox   { background-color: @bg; border-radius: 10px; children: [inputbar, listview]; }
        inputbar  { background-color: @bg-alt; children: [prompt, entry]; }
        entry     { background-color: inherit; padding: 12px 3px; }
        prompt    { background-color: inherit; padding: 12px; }
        listview  { lines: 8; }
        element   { children: [element-text]; }
        element-icon { padding: 10px 10px; }
        element-text {
          padding: 10px 10px;
          text-color: @fg-alt;
        }
        element-text selected { text-color: @fg; }
      ''
    );
  };

  lib.scripts.rofi-comma = pkgs.writeNixShellScript "rofi-comma"
    <| builtins.readFile ./rofi-comma.sh;

  custom.persistence.files = [
    ".cache/rofi-2.sshcache"
    ".cache/rofi-3.runcache"
    ".cache/rofi-4.runcache"
    ".cache/rofi-entry-history.txt"
    ".cache/rofi3.druncache"
  ];
}
