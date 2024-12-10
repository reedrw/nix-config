{ pkgs, ... }:

{
  stylix.targets.vesktop-clienttheme.enable = true;

  home.packages = with pkgs; [
    vesktop
    discord
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
