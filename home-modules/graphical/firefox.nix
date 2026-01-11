{ pkgs, lib, ... }:
let
  myFirefox = with pkgs; wrapFirefox firefox-esr-unwrapped {
    extraPolicies = {
      CaptivePortal = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      FirefoxHome = {
        Pocket = false;
        Snippets = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
      };
    };
  };
in
{

  stylix.targets.firefox = {
    enable = true;
    profileNames = [ "default" ];
  };

  home.sessionVariables = {
    MOZ_USE_XINPUT2 = "1";
  };

  programs.firefox = {
    enable = true;
    package = myFirefox;

    profiles."default" = {
      name = "default";
      userChrome = ''
        .tab-text { font-size: 14px !important; }
      '';
      settings = {
        "font.size.variable.x-western" = lib.mkForce 16;
        "browser.contentblocking.report.lockwise.enabled" = false;
        "browser.contentblocking.report.monitor.enabled" = false;
        "browser.display.use_system_colors" = false;
        "browser.download.useDownloadDir" = false;
        "devtools.theme" = "auto";
        "general.autoScroll" = true;
        "gfx.webrender.all" = true;
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;
        "media.cubeb_latency_playback_ms" = 10;
        "widget.content.allow-gtk-dark-theme" = false;
        "browser.proton.contextmenus.enabled" = false;
        "browser.proton.doorhangers.enabled" = false;
        "browser.proton.enabled" = false;
        "browser.proton.modals.enabled" = false;
        "browser.proton.places-tooltip.enabled" = false;
        "browser.sessionstore.restore_tabs_lazily" = false;
        "browser.sessionstore.restore_on_demand" = false;
      };
    };
  };

  custom.persistence.directories = [
    ".cache/mozilla"
    ".mozilla/firefox"
  ];
}
