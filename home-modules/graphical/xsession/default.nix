{ config, lib, pkgs, ... }:
let
  inherit (config.lib) scripts;

  wallpaper-colored = let
    fileType = config.stylix.image
      |> lib.splitString "."
      |> lib.last;
    filename = "wallpaper.${fileType}";
    colorScheme = config.lib.stylix.colors
      |> lib.getAttrs [
        "base00" "base01" "base02" "base03"
        # "base04" "base05" "base06" "base07"
        # "base08" "base09" "base0A" "base0B"
        # "base0C" "base0D" "base0E" "base0F"
      ]
      |> builtins.attrValues
      |> builtins.concatStringsSep " "
    ;
  in pkgs.runCommandNoCC filename { buildInputs = [ pkgs.lutgen ]; } ''
    lutgen apply -s 36 ${config.stylix.image} -o $out -- ${colorScheme}
  '';

  alwaysRun = with pkgs; [
    "${lib.getExe feh} --bg-fill ${wallpaper-colored} --no-fehbg"
    # "${lib.getExe feh} --bg-fill ${config.stylix.image} --no-fehbg"
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
in
{
  imports = [
    ./keybinds.nix
    ./xdgApps.nix
    ./scripts
  ];

  home.packages = with pkgs; [
    xclip
    xsel
    lockProgram
  ];

  programs.zsh.initExtra = lib.mkAfter ''
    function c(){
      if [[ -p /dev/stdin ]]; then
        xclip -i -selection clipboard
      else
        xclip -o -selection clipboard
      fi
    }
  '';

  home.activation = let
    restartScript = pkgs.writeShellScript "restart" ''
      restartFunc() {
        while pidof i3lock > /dev/null; do
          sleep 1
        done
        i3-msg restart
      }
      restartFunc &
    '';
  in {
    reloadI3 = config.lib.dag.entryAfter ["writeBoundary"] ''
      run ${restartScript}
    '';
  };

  stylix.targets.i3.enable = true;

  xresources.path = "${config.xdg.dataHome}/X11/Xresources";
  xsession = {
    enable = true;
    # profilePath = "${lib.removeHomeDirPrefix config.xdg.dataHome}/X11/xprofile";
    profilePath = ".local/share/X11/xprofile";
    # scriptPath = "${lib.removeHomeDirPrefix config.xdg.dataHome}/X11/xsession";
    scriptPath = ".local/share/X11/xsession";
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
          "Signal"
          "TelegramDesktop"
          "Zathura"
          "easyeffects"
          "firefox"
          "kitty"
          "mpv"
          "vesktop"
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
  xdg.configFile = let
    listDirectory = path:
      builtins.map (x: path + "/${x}") (builtins.attrNames (builtins.readDir path));
  in listDirectory ./.
    |> builtins.filter (lib.hasSuffix ".json")
    |> map (x: lib.last (lib.splitString "/" (toString x)))
    |> map (x: { "i3/${x}".source = "${./.}/${x}"; })
    |> lib.mergeAttrsList;

  services = {
    flameshot.enable = true;
    parcellite = {
      enable = true;
      package = pkgs.clipit;
    };
  };

  systemd.user.services = with config.lib.functions; lib.mergeAttrsList [
    (mkSimpleService "autotiling" (lib.getExe pkgs.autotiling))
    (mkSimpleService "clipboard-clean" (lib.getExe scripts.clipboard-clean))
    (mkSimpleService "dwebp-serv" (lib.getExe scripts.dwebp-serv))
    (mkSimpleService "mpv-dnd" (lib.getExe scripts.mpv-dnd))
    (mkSimpleService "keybinds" (lib.getExe scripts.keybinds))
    (mkSimpleService "droidcam-fix" (lib.getExe scripts.droidcam-fix))
  ];
}
