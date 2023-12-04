{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tdesktop
    (fromBranch.master.discord.override {
      withVencord = true;
      nss = nss_latest;
    })
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
