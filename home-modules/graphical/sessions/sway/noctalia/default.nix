{ config, lib, pkgs, ... }:

let
  inherit (config.lib) scripts;
  polarity = config.stylix.polarity;

  fileType = config.stylix.image
    |> lib.splitString "."
    |> lib.last;
  filename = "wallpaper.${fileType}";
  colorScheme = config.lib.stylix.colors
    |> lib.getAttrs [
        "base00" "base01" "base02" "base03"
        "base04" "base05" "base06" "base07"
        "base08" "base09" "base0A" "base0B"
        "base0C" "base0D" "base0E" "base0F"
      ]
    |> builtins.attrValues
    |> builtins.concatStringsSep " ";

  wallpaper-colored =
    pkgs.runCommand filename { buildInputs = with pkgs; [ lutgen imagemagick ]; } <|
    (lib.optionalString (polarity == "light") ''
      convert ${config.stylix.image} -channel RGB -negate out.${fileType}
    '' + ''
      if test -f "out.${fileType}"; then
        image="out.${fileType}"
      else
        image="${config.stylix.image}"
      fi
      lutgen apply -R --preserve -s 128 $image -o $out -- ${colorScheme}
    '');

  polybarScripts = ../../i3/polybar;

  settings = {
    bar = {
      position = "top";
      barType = "simple";
      backgroundOpacity = 0.93;
      showCapsule = true;
      capsuleOpacity = 1.0;
      frameRadius = 12;
      outerCorners = true;
      marginVertical = 4;
      marginHorizontal = 4;
      widgets = {
        left = [
          { id = "Launcher"; }
          { id = "Workspace"; }
        ];
        center = [
          { id = "MediaMini"; }
        ];
        right = [
          # Screen sessions indicator (hidden when empty)
          {
            id = "CustomButton";
            textCommand = lib.getExe scripts.screenthing;
            textStream = true;
            leftClickExec = "${pkgs.libnotify}/bin/notify-send \"$(screen -ls)\"";
            hideMode = "hidden";
          }
          # Light/dark theme toggle
          {
            id = "CustomButton";
            icon = if polarity == "light" then "weather-clear" else "weather-clear-night";
            showIcon = true;
            textCommand = "";
            leftClickExec = "toggle-theme";
          }
          # Android device indicator (hidden when no device)
          {
            id = "CustomButton";
            textCommand = "${lib.getExe scripts.adb-device} icon";
            textIntervalMs = 10000;
            leftClickExec = lib.getExe scripts.adb-device;
            hideMode = "hidden";
          }
          # Battery (auto-hides when no battery detected)
          { id = "Battery"; displayMode = "graphic-clean"; hideIfNotDetected = true; }
          # Clock — opens noctalia's built-in calendar panel on click
          { id = "Clock"; }
          { id = "NotificationHistory"; }
          { id = "Tray"; }
          { id = "ControlCenter"; }
        ];
      };
    };

    colorSchemes = {
      # Generate colors from the stylix-recolored wallpaper so noctalia's
      # material palette harmonizes with the rest of the desktop.
      useWallpaperColors = true;
      darkMode = polarity == "dark";
    };

    wallpaper = {
      enabled = true;
      setWallpaperOnAllMonitors = true;
      fillMode = "crop";
    };

    idle = {
      enabled = true;
      screenOffTimeout = 600;
      lockTimeout = 660;
      suspendTimeout = 1800;
    };

    general = {
      lockOnSuspend = true;
      showChangelogOnStartup = false;
    };

    notifications = {
      position = "top-right";
    };
  };

in
{
  lib.scripts = {
    screenthing = pkgs.writeShellScriptBin "screenthing" <| builtins.readFile "${polybarScripts}/screenthing.sh";
    bataverage  = pkgs.writeShellScriptBin "bataverage"  <| builtins.readFile "${polybarScripts}/bataverage.sh";
    adb-device  = pkgs.writeNixShellScript "adb-device"  <| builtins.readFile "${polybarScripts}/adb-device.sh";
  };

  home = {
    packages = [ pkgs.noctalia-shell ];

    # Pre-populate version so noctalia's privacy-wizard and changelog dialogs
    # don't fire on first launch. The version must be >= 4.0.2 (telemetry wizard
    # threshold) and ideally matches the installed noctalia-shell version.
    file.".cache/noctalia/shell-state.json" = {
      force = true;
      text = builtins.toJSON { changelogState.lastSeenVersion = pkgs.noctalia-shell.version; };
    };

    # Point noctalia at the stylix-recolored wallpaper.
    file.".cache/noctalia/wallpapers.json" = {
      force = true;
      text = builtins.toJSON { defaultWallpaper = "${wallpaper-colored}"; };
    };
  };

  xdg.configFile."noctalia/settings.json" = {
    force = true;
    text = builtins.toJSON settings;
  };

  # Don't let stylix override noctalia colors — we wire them via wallpaper above.
  stylix.targets.noctalia-shell.enable = false;
}
