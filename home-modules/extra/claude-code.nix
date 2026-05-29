{ config, ... }:
{
  programs.claude-code = {
    enable = true;
    settings.theme = if config.stylix.polarity == "light" then "light-ansi" else "dark-ansi";
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [ ".claude" ];
  };
}
