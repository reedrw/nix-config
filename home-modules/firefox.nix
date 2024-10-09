{ pkgs, ... }:
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
    extraPrefs = ''
      defaultPref("browser.contentblocking.report.lockwise.enabled", false);
      defaultPref("browser.contentblocking.report.monitor.enabled", false);
      defaultPref("browser.display.use_system_colors", false);
      defaultPref("browser.download.useDownloadDir", false);
      defaultPref("devtools.theme", "dark");
      defaultPref("general.autoScroll", true);
      defaultPref("gfx.webrender.all", true);
      defaultPref("media.videocontrols.picture-in-picture.video-toggle.enabled", false)
      defaultPref("media.cubeb_latency_playback_ms", 10);
      defaultPref("widget.content.allow-gtk-dark-theme", false);
      defaultPref("browser.proton.contextmenus.enabled", false);
      defaultPref("browser.proton.doorhangers.enabled", false);
      defaultPref("browser.proton.enabled", false);
      defaultPref("browser.proton.modals.enabled", false);
      defaultPref("browser.proton.places-tooltip.enabled", false);
      defaultPref("browser.sessionstore.restore_tabs_lazily", false);
      defaultPref("browser.sessionstore.restore_on_demand", false);
    '';
  };
in
{

  stylix.targets.firefox.enable = true;

  programs.firefox = {
    enable = true;
    # Exclude firefox from mullvad. I use the FoxyProxy extension
    # with SSH SOCKS5 proxy to localhost to manage proxy in firefox
    # (because private trackers block mullvad).
    package = with pkgs; (emptyDirectory // { override = _: wrapEnv (mullvadExclude myFirefox) {
      # Enable XInput2 for high-resolution mouse scrolling
      MOZ_USE_XINPUT2 = "1";
    }; });

    profiles."default" = {
      name = "default";
      userChrome = ''
        .tab-text { font-size: 14px !important; }
      '';
    };
  };

}
