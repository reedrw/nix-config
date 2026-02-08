{ config, util, pkgs, ... }:
let
  sources = (util.importFlake ./sources).inputs;
in
{
  imports = [
    sources.nixcord.homeModules.nixcord
  ];

  programs.nixcord = {
    enable = true;
    discord = {
      autoscroll.enable = true;
      vencord.package = sources.nixcord.packages.${pkgs.stdenv.hostPlatform.system}.vencord.overrideAttrs (old: {
        src = sources.vencord // {
          inherit (old.src) owner repo;
        };
      });
    };
    config = {
      frameless = true;
      plugins = {
        betterSettings.enable = true;
        betterUploadButton.enable = true;
        ClearURLs.enable = true;
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
        normalizeMessageLinks.enable = true;
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

  home.activation.extraDiscordSettings = let
    extraSettings = {
      OPEN_ON_STARTUP = false;
      MINIMIZE_TO_TRAY = false;
    };
  in config.lib.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail
    mkdir -p "${config.programs.nixcord.discord.configDir}"
    config_dir="${config.programs.nixcord.discord.configDir}"
    if [ -f "$config_dir/settings.json" ]; then
      jq '. + ${builtins.toJSON extraSettings}' "$config_dir/settings.json" > "$config_dir/settings.json.tmp" && mv "$config_dir/settings.json.tmp" "$config_dir/settings.json"
    else
      echo '${builtins.toJSON extraSettings}' > "$config_dir/settings.json"
    fi
  '';

  custom.persistence.directories = [
    ".config/discord"
  ];
}
