{ util, ... }:
let
  sources = (util.importFlake ./sources).inputs;
in
{
  imports = [
    sources.nixcord.homeModules.nixcord
  ];

  programs.nixcord = {
    enable = true;
    discord.enable = false;
    vesktop = {
      enable = true;
      autoscroll.enable = true;
      settings = {
        minimizeToTray = false;
        enableSplashScreen = false;
      };
    };
    config = {
      frameless = true;
      themeLinks = [
        "https://raw.codeberg.page/AllPurposeMat/Disblock-Origin/DisblockOrigin.theme.css"
      ];
      plugins = {
        betterSettings.enable = true;
        betterUploadButton.enable = true;
        ClearURLs.enable = true;
        disableCallIdle.enable = true;
        fakeNitro = {
          enable = true;
          transformCompoundSentence = true;
        };
        fixImagesQuality.enable = true;
        fixYoutubeEmbeds.enable = true;
        iLoveSpam.enable = true;
        loadingQuotes.enable = true;
        messageLinkEmbeds.enable = true;
        noBlockedMessages.enable = true;
        replaceGoogleSearch = {
          enable = true;
          customEngineName = "DuckDuckGo";
          customEngineURL = "https://duckduckgo.com/";
        };
        silentTyping = {
          enable = true;
          chatContextMenu = true;
          enabledGlobally = false;
          chatIcon = true;
        };
        translate.enable = true;
        typingIndicator.enable = true;
        unindent.enable = true;
        voiceMessages.enable = true;
        youtubeAdblock.enable = true;
      };
    };
  };

  custom.persistence.directories = [
    ".config/vesktop"
  ];
}
