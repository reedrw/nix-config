{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    tdesktop
    discord-canary
    element-desktop
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
