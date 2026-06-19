{ config, lib, pkgs, ... }:

let
  colors = config.lib.stylix.colors;
  polarity = config.stylix.polarity;
  lightDarkIcon = if polarity == "light" then " " else "󰃠 ";

  adb-device      = pkgs.writeNixShellScript "adb-device"      <| builtins.readFile ./adb-device.sh;
  airpods-battery = pkgs.writeNixShellScript "airpods-battery" <| builtins.readFile ./airpods-battery.sh;
  calnotify       = pkgs.writeNixShellScript "calnotify"       <| builtins.readFile ./calnotify.sh;

  # Screenthing without the polybar tail-sleep; SCREENDIR must be explicit
  # because the systemd user service doesn't inherit it from the login shell.
  screenExec = pkgs.writeShellScriptBin "waybar-screen" ''
    export SCREENDIR="${config.xdg.dataHome}/screen"
    a=$(screen -ls | tail -1 | grep "Socket")
    arr=($a)
    if [[ "''${arr[0]}" != "No" ]]; then
      echo "''${arr[0]} ''${arr[1]}"
    fi
  '';

  # Battery average without the polybar tail-sleep
  batteryExec = pkgs.writeShellScriptBin "waybar-battery" ''
    if command -v acpi &>/dev/null && acpi 2>/dev/null | grep -q "Battery"; then
      charging=$(acpi -a 2>/dev/null | grep -c "on-line" || echo 0)
      pct=$(acpi | grep -v "rate information unavailable" \
        | sed -e 's/%.*$//g' -e 's/^.*, //g' \
        | awk '{ sum += $1; n++ } END { if (n > 0) printf "%d%%", int(sum/n) }')
      if [ "$charging" -gt 0 ]; then
        echo "$pct+"
      else
        echo "$pct"
      fi
    fi
  '';
in
{
  lib.scripts = { inherit adb-device calnotify; };

  stylix.targets.waybar.enable = false;

  programs.waybar = with colors; {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "sway-session.target" ];
    };

    settings = [
      {
        layer = "top";
        position = "top";
        height = 28;

        modules-left   = [ "sway/workspaces" ];
        modules-center = [ "mpris" ];
        modules-right  = [
          "custom/screen"
          "custom/light-dark"
          "custom/airpods-battery"
          "custom/adb-device"
          "custom/battery"
          "clock"
        ];

        "sway/workspaces" = {
          format = "{name}";
          sort-by-number = true;
        };

        mpris = {
          format = "{artist} - {title}";
          format-paused = "{artist} - {title}";
          format-stopped = "";
          on-click = "${lib.getExe pkgs.playerctl} play-pause";
        };

        "custom/screen" = {
          exec = lib.getExe screenExec;
          interval = 5;
          on-click = "${pkgs.libnotify}/bin/notify-send \"$(screen -ls)\"";
          return-type = "";
        };

        "custom/light-dark" = {
          exec = ''echo '${lightDarkIcon}' '';
          interval = 0;
          on-click = "toggle-theme";
          return-type = "";
        };

        "custom/airpods-battery" = {
          exec = "${lib.getExe airpods-battery} icon";
          interval = 10;
          on-click = lib.getExe airpods-battery;
          return-type = "";
        };

        "custom/adb-device" = {
          exec = "${lib.getExe adb-device} icon";
          interval = 10;
          on-click = lib.getExe adb-device;
          return-type = "";
        };

        "custom/battery" = {
          exec = lib.getExe batteryExec;
          interval = 30;
          on-click = "${pkgs.libnotify}/bin/notify-send \"$(${pkgs.acpi}/bin/acpi | sed -e 's/%[^,]*/%/g')\"";
          return-type = "";
        };

        clock = {
          format    = "{:%I:%M %p    %a %b %d}";
          tooltip   = false;
          on-click  = "${lib.getExe calnotify} ${base0B}";
        };
      }
    ];

    style = with colors; ''
      * {
        font-family: "FantasqueSansMNerdFont", "Kochi Gothic";
        font-size: 9pt;
        font-weight: bold;
        border: none;
        border-radius: 0;
        padding: 0;
        margin: 0;
        box-shadow: none;
        text-shadow: none;
      }

      window#waybar {
        background-color: #${base00};
        color: #${base05};
        min-height: 28px;
      }

      .modules-left  { padding-left:  1px; }
      .modules-right { padding-right: 1px; }

      #workspaces button {
        padding: 0 4px;
        background: transparent;
        color: #${base03};
        min-height: 28px;
      }

      #workspaces button:hover {
        background: transparent;
        box-shadow: none;
        text-shadow: none;
      }

      #workspaces button.focused,
      #workspaces button.active {
        color: #${base05};
        background: transparent;
      }

      #workspaces button.urgent {
        color: #${base09};
      }

      #mpris,
      #clock,
      #custom-screen,
      #custom-light-dark,
      #custom-adb-device,
      #custom-battery {
        padding: 0 8px;
        color: #${base05};
        min-height: 28px;
      }

    '';
  };
}
