{ config, pkgs, ... }:
{
  home.packages = [ pkgs.claude-code ];

  home.file.".claude/settings.json" = {
    force = true;
    text = builtins.toJSON {
      theme = if config.stylix.polarity == "light" then "light-ansi" else "dark-ansi";
    };
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [ ".claude" ];
  };
}
