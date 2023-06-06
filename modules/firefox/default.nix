{ pkgs, ... }:
let
  myFirefox = pkgs.wrapFirefox pkgs.firefox-unwrapped {
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
      defaultPref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[\"0nd1g3vr9vbpk6hqixsg1dqyh7pi075b7fiir4706khlapk7kcrb_styl-us-browser-action\",\"1m4slqpfbximmf4igvp2dfl0x55rmyal97kv1ra1j6506w6n1bjv_sponsorblock-browser-action\",\"1h768ljlh3pi23l27qp961v1hd0nbj2vasgy11bmcrlqp40zgvnr_ublock-origin-browser-action\",\"17h1yy8k4l3kqbjbz84avg9jqaa0cl9x19ri76vlflz7ks54i7fs_privacy-badger17-browser-action\",\"1pvdb0fz7jqbzwlrhdkjxhafai70bncywdsx3qsw3325d28hcm15_decentraleyes-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"downloads-button\",\"library-button\",\"sidebar-button\",\"fxa-toolbar-menu-button\",\"1xjfh56znkxffi4kmcrsxqhf3kaal17rc58v1a77p0xx0n8b2kfr_duckduckgo-for-firefox-browser-action\",\"1slqrzp8h1sqy758qljyl5f1ah3c57710iwpin0dnq0c6hfmg045_bitwarden-password-manager-browser-action\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"1xjfh56znkxffi4kmcrsxqhf3kaal17rc58v1a77p0xx0n8b2kfr_duckduckgo-for-firefox-browser-action\",\"0nd1g3vr9vbpk6hqixsg1dqyh7pi075b7fiir4706khlapk7kcrb_styl-us-browser-action\",\"1h768ljlh3pi23l27qp961v1hd0nbj2vasgy11bmcrlqp40zgvnr_ublock-origin-browser-action\",\"1m4slqpfbximmf4igvp2dfl0x55rmyal97kv1ra1j6506w6n1bjv_sponsorblock-browser-action\",\"1slqrzp8h1sqy758qljyl5f1ah3c57710iwpin0dnq0c6hfmg045_bitwarden-password-manager-browser-action\",\"developer-button\",\"17h1yy8k4l3kqbjbz84avg9jqaa0cl9x19ri76vlflz7ks54i7fs_privacy-badger17-browser-action\",\"1pvdb0fz7jqbzwlrhdkjxhafai70bncywdsx3qsw3325d28hcm15_decentraleyes-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"widget-overflow-fixed-list\",\"toolbar-menubar\",\"TabsToolbar\",\"PersonalToolbar\"],\"currentVersion\":16,\"newElementCount\":3}");
      defaultPref("devtools.theme", "dark");
      defaultPref("general.autoScroll", true);
      defaultPref("gfx.webrender.all", true);
      defaultPref("media.videocontrols.picture-in-picture.video-toggle.enabled", false)
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

  # Exclude firefox from mullvad. I use the FoxyProxy extension
  # with SSH SOCKS5 proxy to localhost to manage proxy in firefox
  # (because private trackers block mullvad).
  pkg = pkgs.symlinkJoin rec {
    name = "firefox";
    paths = [ myFirefox ];
    postBuild = ''
      mv $out/bin/firefox $out/bin/.firefox-mullvad-unwrapped
      cat << _EOF > $out/bin/firefox
      #! ${pkgs.runtimeShell} -e
      if [[ -f /run/wrappers/bin/mullvad-exclude ]]; then
        exec /run/wrappers/bin/mullvad-exclude $out/bin/.firefox-mullvad-unwrapped "\$@"
      else
        exec $out/bin/.firefox-mullvad-unwrapped "\$@"
      fi
      _EOF
      chmod 0755 $out/bin/firefox
    '';
  };

in
{

  programs.firefox = {
    enable = true;
    package = (pkgs.emptyDirectory // { override = _: pkg; });
  };

}
