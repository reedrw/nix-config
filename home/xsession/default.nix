{ config, lib, pkgs, ... }:
let
  alwaysRun = with pkgs; [
    "${lib.getExe feh} --bg-fill ${./wallpaper.jpg} --no-fehbg"
    "systemctl --user restart picom"
    "systemctl --user restart autotiling"
    "systemctl --user restart easyeffects"
    "systemctl --user restart playerctld"
    "systemctl --user import-environment PATH"
    "systemctl --user restart xdg-desktop-portal.service"
    "${lib.getExe scripts.toggle-touchpad} disable --silent"
  ];

  run = [
    "i3-msg workspace 1"
    "${pkgs.writeShellScript "remove-xsession-errors" ''
      sleep 5
      for i in ~/.xsession-errors*; do
        if [[ "$(stat -c%s "$i")" == "0" ]]; then
          rm "$i"
        fi
      done
    ''}"
  ];

  scripts = pkgs.callPackage ./scripts { };

in
{
  imports = [
    ./keybinds.nix
  ];

  xresources.path = "${config.xdg.dataHome}/X11/Xresources";
  xsession = {
    enable = true;
    profilePath = "${pkgs.removeHomeDirPrefix config.xdg.dataHome}/X11/xprofile";
    scriptPath = "${pkgs.removeHomeDirPrefix config.xdg.dataHome}/X11/xsession";
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3;
      config = {
        bars = [ ];
        gaps = {
          inner = 7;
        };
        window.border = 5;
        window.titlebar = false;
        floating.border = 5;
        floating.titlebar = false;
        modifier = "Mod1";
        terminal = config.home.sessionVariables.TERMINAL;
        colors = with config.colorScheme.palette; let
          focused = lib.genAttrs [
            "border" "childBorder" "background" "text" "indicator"
          ] (_: "#${base07}");
          inactive = lib.genAttrs [
            "border" "childBorder" "background" "text" "indicator"
          ] (_: "#${base03}");
        in {
          inherit focused;
          focusedInactive = inactive;
          unfocused = inactive;
          urgent = inactive;
        };
        window.commands = [
          {
            command = "floating enable";
            criteria = {
              class = "Alacritty";
              title = "float";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "An Anime Game Launcher";
            };
          }
          {
            command = "floating enable";
            criteria = {
              class = "The Honkers Railway Launcher";
            };
          }
        ] ++ map ( class: {
          command = "border pixel 0";
          criteria = {
            inherit class;
          };
        }) [
          "firefox"
          "mpv"
          "Alacritty"
          "kitty"
          "TelegramDesktop"
          "Element"
          "easyeffects"
          "vesktop"
          "Pavucontrol"
          "Zathura"
          ".blueman-manager-wrapped"
          ".gamescope-wrapped"
        ];
        startup = map ( command: {
          inherit command;
          always = true;
          notification = false;
        }) alwaysRun ++ map ( command: {
          inherit command;
          notification = false;
        }) run;
      };
    };
  };

  xdg.configFile = {
    "i3/workspace-1.json".source = ./workspace-1.json;
    "i3/workspace-2.json".source = ./workspace-2.json;
    "i3/workspace-4.json".source = ./workspace-4.json;
  };

  services = {
    flameshot.enable = true;
    parcellite = {
      enable = true;
      package = pkgs.clipit;
    };
  };

  systemd.user.services = with pkgs; mergeAttrs [
    (mkSimpleHMService "autotiling" "${lib.getExe autotiling}")
    (mkSimpleHMService "clipboard-clean" "${lib.getExe scripts.clipboard-clean}")
    (mkSimpleHMService "dwebp-serv" "${lib.getExe scripts.dwebp-serv}")
    (mkSimpleHMService "mpv-dnd" "${lib.getExe scripts.mpv-dnd}")
    (mkSimpleHMService "keybinds" "${lib.getExe scripts.keybinds}")
  ];
}
