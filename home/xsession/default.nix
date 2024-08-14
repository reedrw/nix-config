{ config, lib, pkgs, ... } @ args:
let
  alwaysRun = with pkgs; [
    "${lib.getExe feh} --bg-fill ${config.stylix.image} --no-fehbg"
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

  scripts = pkgs.callPackage ./scripts args;

in
{
  imports = [
    ./keybinds.nix
    ./xdgApps.nix
  ];

  home.packages = [ pkgs.lockProgram ];

  home.activation = {
    reloadI3 = config.lib.dag.entryAfter ["writeBoundary"] ''
      run i3-msg restart
    '';
  };

  stylix.targets.i3.enable = true;

  xresources.path = "${config.xdg.dataHome}/X11/Xresources";
  xsession = {
    enable = true;
    profilePath = "${lib.removeHomeDirPrefix config.xdg.dataHome}/X11/xprofile";
    scriptPath = "${lib.removeHomeDirPrefix config.xdg.dataHome}/X11/xsession";
    windowManager.i3 = {
      enable = true;
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
        window.commands = let
          commandForWindows = { command }: map (window: {
            inherit command;
            criteria = if builtins.isAttrs window
              then window else {
                class = window;
              };
          });
        in [ ]
        ++ commandForWindows {
          command = "floating enable";
        } [
          "An Anime Game Launcher"
          "The Honkers Railway Launcher"
          "Honkers Launcher"
          "Sleepy Launcher"
          {
            class = "Alacritty";
            title = "float";
          }
        ]
        ++ commandForWindows {
          command = "border pixel 0";
        } [
          "firefox"
          "mpv"
          "kitty"
          "TelegramDesktop"
          "easyeffects"
          "vesktop"
          "Zathura"
        ]
        ++ commandForWindows {
          command = "fullscreen enable";
        } [
          "mpv"
          {
            class = "TelegramDesktop";
            title = "Media viewer";
          }
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

  # link all json files (saved workspaces) in the current directory to ~/.config/i3/
  xdg.configFile = lib.pipe (lib.listDirectory ./.) [
    (builtins.filter (lib.hasSuffix ".json"))
    (map (x: lib.last (lib.splitString "/" (toString x))))
    (map (x: { "i3/${x}".source = ./. + "/${x}"; }))
    (lib.mergeAttrsList)
  ];

  services = {
    flameshot.enable = true;
    parcellite = {
      enable = true;
      package = pkgs.clipit;
    };
  };

  systemd.user.services = let
    mkSimpleService = name: ExecStart: {
      ${name} = {
        Unit = {
          Description = "${name}";
          After = [ "graphical.target" ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          inherit ExecStart;
          Restart = "on-failure";
          RestartSec = 5;
          Type = "simple";
        };
      };
    };
  in with lib; mergeAttrsList [
    (mkSimpleService "autotiling" "${getExe pkgs.autotiling}")
    (mkSimpleService "clipboard-clean" "${getExe scripts.clipboard-clean}")
    (mkSimpleService "dwebp-serv" "${getExe scripts.dwebp-serv}")
    (mkSimpleService "mpv-dnd" "${getExe scripts.mpv-dnd}")
    (mkSimpleService "keybinds" "${getExe scripts.keybinds}")
    (mkSimpleService "droidcam-fix" "${getExe scripts.droidcam-fix}")
  ];
}
