{ pkgs, ... }:
let
  nixcord = (pkgs.importFlake ./sources).inputs.nixcord;
in
{
  imports = [
    nixcord.homeModules.nixcord
  ];

  programs.nixcord = {
    enable = true;
    discord = {
      autoscroll.enable = true;
    };
    config.plugins = {
      youtubeAdblock.enable = true;
      betterUploadButton.enable = true;
      clearURLs.enable = true;
      fakeNitro.enable = true;
      iLoveSpam.enable = true;
      loadingQuotes.enable = true;
      messageLinkEmbeds.enable = true;
      noBlockedMessages.enable = true;
      normalizeMessageLinks.enable = true;
      silentTyping = {
        enable = true;
        showIcon = true;
        contextMenu = true;
        isEnabled = false;
      };
      translate.enable = true;
      typingIndicator.enable = true;
      unindent.enable = true;
      voiceMessages.enable = true;
      fixImagesQuality.enable = true;
      fixYoutubeEmbeds.enable = true;
      betterSettings.enable = true;
      replaceGoogleSearch = {
        enable = true;
        customEngineName = "DuckDuckGo";
        customEngineURL = "https://duckduckgo.com/";
      };
    };
  };
}
