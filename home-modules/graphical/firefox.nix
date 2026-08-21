{ pkgs, lib, config, osConfig, ... }:
let
  inherit (osConfig.custom.display) dp;
  inherit (config.lib.stylix) colors;
  inherit (config.stylix) polarity;
  # stylix pins every Firefox Color accent border to base0D (too vivid);
  # blend borders into their surrounding background instead.
  mkColor = color: {
    r = colors."${color}-rgb-r";
    g = colors."${color}-rgb-g";
    b = colors."${color}-rgb-b";
  };
  mutedAccent = mkColor "base04";
  surfaceBg = mkColor "base00";
  # a small step toward the foreground shade, for surfaces that should read
  # as subtly distinct from the page background without standing out.
  # base02 is too big a step once base00 is a near-white light background.
  elevatedBg = mkColor (if polarity == "dark" then "base02" else "base01");
  # the active tab should always read lighter than the strip around it, but
  # base00 is the lightest shade in light schemes and the darkest in dark
  # ones, so which slot plays "the strip" vs "the active tab" has to flip
  tabStripBg = if polarity == "dark" then surfaceBg else mkColor "base01";
  activeTabBg = if polarity == "dark" then elevatedBg else surfaceBg;
in
{

  stylix.targets.firefox = {
    enable = true;
    profileNames = [ "default" ];
    colorTheme.enable = true;
  };

  home.sessionVariables = {
    MOZ_USE_XINPUT2 = "1";
  };

  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";
    package = pkgs.wrapFirefox pkgs.firefox-esr-unwrapped {
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

    profiles."default" = {
      name = "default";
      extensions.force = true;
      userChrome = ''
        .tab-text { font-size: ${toString (dp 14)}px !important; }
        :root { --focus-outline-color: transparent !important; }
      '';
      extensions.settings."FirefoxColor@mozilla.com".settings.theme.colors = {
        frame = lib.mkForce tabStripBg;
        tab_selected = lib.mkForce activeTabBg;
        tab_line = lib.mkForce tabStripBg;
        tab_background_separator = lib.mkForce tabStripBg;
        popup_border = lib.mkForce surfaceBg;
        sidebar_border = lib.mkForce surfaceBg;
        sidebar_highlight = lib.mkForce surfaceBg;
        toolbar_field = lib.mkForce elevatedBg;
        toolbar_field_border_focus = lib.mkForce elevatedBg;
        toolbar_field_separator = lib.mkForce elevatedBg;
        toolbar_vertical_separator = lib.mkForce surfaceBg;
        # selected-text background in the url bar; paired with a fixed dark
        # text color upstream, so must stay light, not blended into the bg
        toolbar_field_highlight = lib.mkForce mutedAccent;
        icons_attention = lib.mkForce mutedAccent;
        # selected urlbar/menu suggestion background; stylix's base04 was
        # too close to its paired base05 text color in ayu-dark to read
        popup_highlight = lib.mkForce activeTabBg;
      };
      settings = {
        "font.size.variable.x-western" = lib.mkForce (dp 16);
        "browser.contentblocking.report.lockwise.enabled" = false;
        "browser.contentblocking.report.monitor.enabled" = false;
        "browser.tabs.groups.enabled" = false;
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
        "javascript.options.wasm_js_promise_integration" = true;
      };
    };
  };

  custom.persistence.directories = [
    ".cache/mozilla"
    ".mozilla/firefox"
  ];
}
