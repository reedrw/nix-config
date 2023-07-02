{ config, pkgs, ... }:
let
  calnotify = pkgs.writeNixShellScript "calnotify" (builtins.readFile ./calnotify.sh);
  screenthing = pkgs.writeShellScriptBin "screenthing" (builtins.readFile ./screenthing.sh);
  # Average battery capacities together cuz my laptop has 2 internal batteries
  bataverage = pkgs.writeShellScriptBin "bataverage" (builtins.readFile ./bataverage.sh);
in
{
  home.packages = with pkgs; [ nurPkgs.artwiz-lemon ]; # font
  services.polybar = with pkgs; {
    enable = true;
    package = polybarFull;
    config = with config.colorScheme.colors; {
      "bar/main" = {
        background = "#${base00}";
        foreground = "#${base05}";
        modules-left = "i3";
        modules-center = "mpris";
        modules-right = "screen battery date";
        border-left-size = 1;
        border-left-color = "#${base00}";
        border-right-size = 1;
        border-right-color = "#${base00}";
        border-top-size = 2;
        border-top-color = "#${base00}";
        border-bottom-size = 2;
        border-bottom-color = "#${base00}";
        font-0 = "lemon:pixelsize=10;1";
        font-1 = "Kochi Gothic:size=8;1";
      };
      "module/battery" = {
        type = "custom/script";
        exec = "${binPath bataverage}";
        tail = true;
      };
      "module/date" = {
        type = "internal/date";
        date = "%I:%M %p    %a %b %d";
        label = "%{A1:${binPath calnotify} ${base0B}:}%date%%{A}";
        format = "<label>";
        label-padding = 4;
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
        exec = "${binPath playerctl} metadata -F --format '{{ artist }} - {{ title }}'";
        click-left = "${binPath playerctl} play-pause";
        tail = true;
      };
      "module/screen" = {
        type = "custom/script";
        exec = "${binPath screenthing}";
        click-left = ''${libnotify}/bin/notify-send "$(screen -ls)"'';
        label-padding = 4;
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
