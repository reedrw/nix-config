{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Mirrors home-manager's programs/pi-coding-agent module (not yet in release-26.05):
  # extraPackages wrap + declarative settings.json with pi packages.
  jsonFormat = pkgs.formats.json { };

  # Everything in ./plugins is installed automatically: *.ts files as
  # extensions, everything else (vendored or pinned npm — see plugins/) as
  # local-dir packages. Install/uninstall by editing the plugins dir or
  # pins.json (then run its update.sh).
  # callPackage wraps its result with override helpers; strip them so the set
  # is uniformly iterable.
  plugins = builtins.removeAttrs (pkgs.callPackage ./plugins { }) [
    "override"
    "overrideDerivation"
  ];

  extensionPlugins = lib.filterAttrs (_: p: p.passthru.piKind == "extension") plugins;
  libPlugins = lib.filterAttrs (_: p: p.passthru.piKind == "lib") plugins;
  dirPlugins = lib.filterAttrs (_: p: p.passthru.piKind == "package") plugins;

  extensionFiles = lib.listToAttrs (
    lib.mapAttrsToList (name: plugin: {
      name = ".pi/agent/extensions/${name}.ts";
      value = {
        force = true;
        source = "${plugin}/${name}.ts";
      };
    }) extensionPlugins
  );

  # Shared extension libraries (pi doesn't auto-load extensions/lib/*, but the
  # extensions' ./lib/… relative imports resolve there at runtime).
  libFiles = lib.listToAttrs (
    lib.mapAttrsToList (name: plugin: {
      name = ".pi/agent/extensions/${name}.ts";
      value = {
        force = true;
        source = "${plugin}/${name}.ts";
      };
    }) libPlugins
  );

  dirPackageFiles = lib.listToAttrs (
    lib.mapAttrsToList (name: plugin: {
      name = ".pi/agent/${name}";
      value = {
        force = true;
        source = plugin;
      };
    }) dirPlugins
  );

  # Stylix base16 scheme attrs (base00..base0F, hex without '#'). Consumed
  # twice: extensions/lib/base16.json (custom-ui TUI colors) and the pi theme
  # below — both follow terminal theme changes instead of being hardcoded.
  scheme = config.stylix.base16.mkSchemeAttrs config.stylix.base16Scheme;

  base16Json = jsonFormat.generate "pi-base16.json" (
    lib.getAttrs
      (map (b: "base${b}") [
        "00" "01" "02" "03" "04" "05" "06" "07"
        "08" "09" "0A" "0B" "0C" "0D" "0E" "0F"
      ])
      scheme
  );

  # ── pi theme generated from the stylix scheme ─────────────────
  # Port of https://github.com/nix-community/stylix/pull/2488. We don't use
  # the upstream module itself (it's gated behind home-manager's
  # programs.pi-coding-agent option, which we mirror by hand here); we just
  # reuse its base16 → pi-token mapping. Covers all 51 required tokens.
  hexPairToInt = pair: builtins.fromJSON "${toString (lib.fromHexString pair)}";

  hexToRgb =
    value:
    let
      hexValue = lib.removePrefix "#" value;
    in
    {
      r = hexPairToInt (builtins.substring 0 2 hexValue);
      g = hexPairToInt (builtins.substring 2 2 hexValue);
      b = hexPairToInt (builtins.substring 4 2 hexValue);
    };

  channelToHex = value: lib.fixedWidthString 2 "0" (lib.toHexString (lib.min 255 (lib.max 0 value)));

  rgbToHex = rgb: "#${channelToHex rgb.r}${channelToHex rgb.g}${channelToHex rgb.b}";

  # Linear blend of two hex colors; weight 0 = left, 1 = right. Used to
  # derive translucent-looking backgrounds (selection, tool boxes, …) from
  # the scheme's surfaces instead of hardcoding them.
  mix =
    weight: left: right:
    let
      a = hexToRgb left;
      b = hexToRgb right;
      blend = x: y: builtins.floor ((1.0 - weight) * x + weight * y);
    in
    rgbToHex {
      r = blend a.r b.r;
      g = blend a.g b.g;
      b = blend a.b b.b;
    };

  piTheme =
    let
      c = name: "#${scheme.${name}}";
      base = c "base00";
      surface = c "base01";
      surfaceAlt = c "base02";
      overlay = c "base03";
      muted = c "base04";
      text = c "base05";
      red = c "base08";
      orange = c "base09";
      yellow = c "base0A";
      green = c "base0B";
      cyan = c "base0C";
      blue = c "base0D";
      purple = c "base0E";

      selected = mix 0.14 surfaceAlt blue;
      userBg = mix 0.04 surface text;
      customBg = mix 0.10 surface purple;
      pendingBg = mix 0.10 surface cyan;
      successBg = mix 0.12 surface green;
      errorBg = mix 0.12 surface red;
      exportInfoBg = mix 0.12 surface yellow;
    in
    {
      "$schema" = "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
      name = "stylix";

      vars = {
        inherit
          base
          surface
          surfaceAlt
          overlay
          muted
          text
          red
          orange
          yellow
          green
          cyan
          blue
          purple
          selected
          userBg
          customBg
          pendingBg
          successBg
          errorBg
          ;
      };

      colors = {
        accent = "blue";
        border = "overlay";
        borderAccent = "blue";
        borderMuted = "muted";
        success = "green";
        error = "red";
        warning = "yellow";
        muted = "muted";
        dim = "overlay";
        text = "text";
        thinkingText = "muted";

        selectedBg = "selected";
        userMessageBg = "userBg";
        userMessageText = "text";
        customMessageBg = "customBg";
        customMessageText = "text";
        customMessageLabel = "purple";
        toolPendingBg = "pendingBg";
        toolSuccessBg = "successBg";
        toolErrorBg = "errorBg";
        toolTitle = "text";
        toolOutput = "muted";

        mdHeading = "yellow";
        mdLink = "blue";
        mdLinkUrl = "muted";
        mdCode = "cyan";
        mdCodeBlock = "text";
        mdCodeBlockBorder = "overlay";
        mdQuote = "muted";
        mdQuoteBorder = "overlay";
        mdHr = "overlay";
        mdListBullet = "cyan";

        toolDiffAdded = "green";
        toolDiffRemoved = "red";
        toolDiffContext = "muted";

        syntaxComment = "muted";
        syntaxKeyword = "purple";
        syntaxFunction = "blue";
        syntaxVariable = "red";
        syntaxString = "green";
        syntaxNumber = "orange";
        syntaxType = "yellow";
        syntaxOperator = "text";
        syntaxPunctuation = "muted";

        thinkingOff = "overlay";
        thinkingMinimal = "muted";
        thinkingLow = "cyan";
        thinkingMedium = "blue";
        thinkingHigh = "purple";
        thinkingXhigh = "red";
        thinkingMax = "orange";

        bashMode = "yellow";
      };

      export = {
        pageBg = base;
        cardBg = surface;
        infoBg = exportInfoBg;
      };
    };
in
{
  home = {
    # Through the alias overlay so pkgs/patches-style tweaks (wheel scroll
    # speed) apply; no wrapper needed — nix-locate (for nix-comma.ts) is
    # already on PATH via home.packages in home-modules/core/comma/default.nix.
    packages = [ pkgs.pi-coding-agent ];

    # pi-output-styles keeps its user default (/style … --save) and custom
    # styles under $PI_OUTPUT_STYLES_HOME instead of ~/.omp/agent.
    sessionVariables.PI_OUTPUT_STYLES_HOME = "${config.home.homeDirectory}/.pi/agent";

    file = extensionFiles // libFiles // dirPackageFiles // {
      # Palette consumed by lib/custom-ui.ts (see base16Json above).
      ".pi/agent/extensions/lib/base16.json" = {
        force = true;
        source = base16Json;
      };
      # pi theme generated from the stylix scheme (see piTheme above);
      # selected via settings.json theme = "stylix".
      ".pi/agent/themes/stylix.json" = {
        force = true;
        source = jsonFormat.generate "pi-theme-stylix.json" piTheme;
      };
      # pi-web-access config: skip the browser curator ("none") so
      # web_search returns raw results. Lives under XDG_CONFIG_HOME (not
      # ~/.pi) because pi-web-access resolves its config dir from
      # XDG_CONFIG_HOME when set. Note: pi's /curator command and provider
      # changes in the curator UI persist to this file — those writes will
      # fail while it's a read-only nix store symlink.
      ".config/pi/web-search.json" = {
        force = true;
        source = jsonFormat.generate "pi-web-search.json" {
          workflow = "none";
        };
      };
      ".pi/agent/settings.json" = {
        force = true;
        source = jsonFormat.generate "pi-settings.json" {
          lastChangelogVersion = "0.84.2";
          defaultProvider = "openrouter";
          defaultModel = "z-ai/glm-5.3-flash";
          defaultThinkingLevel = "high";
          theme = "stylix";
          tuiMode = "fullscreen";
          packages = lib.mapAttrsToList (name: _: "./${name}") dirPlugins;
          # Claude Code style tool rendering (one-line calls, terse results).
          # Flip to false to fall back to pi's default boxed tool rendering;
          # takes effect on restart or /reload.
          customUi = true;
          # custom-ui renders tool-result images inside the tool row via
          # kitty placeholders; disable pi's built-in Image path, which draws
          # outside the box (and is tmux-disabled anyway).
          terminal.showImages = false;
        };
      };
    };
  };

  # .pi/agent/styles holds pi-output-styles user state (covered by the .pi
  # persistence below).
  custom.persistence.directories = [ ".pi" ];
}
