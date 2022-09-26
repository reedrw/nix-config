{ config, lib, pkgs, ... }:
let
  calnotify = pkgs.writeShellApplication {
    name = "calnotify";
    runtimeInputs = with pkgs; [
      util-linux
      gnused
      libnotify
    ];
    text = (builtins.readFile ./calnotify.sh);
  };
in
{
  home.packages = [ pkgs.nur.repos.reedrw.artwiz-lemon ]; # font
  services.polybar = {
    enable = true;
    package = pkgs.polybarFull;
    config = with config.colorScheme.colors; {
      "bar/main" = {
        background = "#${base00}";
        foreground = "#${base05}";
        modules-left = "i3";
        modules-center = "mpris";
        modules-right = "battery date";
        border-left-size = 1;
        border-left-color = "#${base00}";
        border-right-size = 1;
        border-right-color = "#${base00}";
        border-top-size = 2;
        border-top-color = "#${base00}";
        border-bottom-size = 2;
        border-bottom-color = "#${base00}";
        font-0 = "lemon:pixelsize=10;1";
      };
      "module/battery" = {
        type = "internal/battery";
      };
      "module/date" = {
        type = "internal/date";
        date = "%I:%M %p    %a %b %d";
        label = "%{A1:${calnotify}/bin/calnotify ${base0B}:}%date%%{A}";
        format = "<label>";
        label-padding = 5;
      };
      "module/i3" = {
        type = "internal/i3";
        label-unfocused-foreground = "#${base03}";
        label-urgent-foreground = "#${base09}";
        label-unfocused-padding = 1;
        label-focused-padding = 1;
        label-urgent-padding = 1;
      };
      "module/mpris" = {
        type = "custom/script";
        exec = "${pkgs.playerctl}/bin/playerctl metadata -F --format '{{ artist }} - {{ title }}'";
        click-left = "${pkgs.playerctl}/bin/playerctl play-pause";
        tail = true;
      };
    };
    script = "";
  };
  # Calendar script doesn't work when polybar is run as service
  # for some reason
  # https://github.com/nix-community/home-manager/issues/1616
  xsession.windowManager.i3.config.startup = [
    {
      command = "pkill polybar";
      always = true;
      notification = false;
    }
    {
      command = "sh -c 'sleep 0.5; polybar main &'";
      always = true;
      notification = false;
    }
  ];
}
