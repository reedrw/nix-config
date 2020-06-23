{ config, lib, pkgs, ... }:


{
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3Support = true;
    };
    config = with config.lib.base16.theme; {
      "bar/main" = {
        background = "#${base00-hex}";
        foreground = "#${base05-hex}";
        modules-left = "i3";
        modules-right = "battery date";
        border-left-size = 1;
        border-left-color = "#${base00-hex}";
        border-right-size = 1;
        border-right-color = "#${base00-hex}";
        border-top-size = 2;
        border-top-color = "#${base00-hex}";
        border-bottom-size = 2;
        border-bottom-color = "#${base00-hex}";
        font-0 = "lemon:pixelsize=10;1";
      };
      "module/battery" = {
        type = "internal/battery";
      };
      "module/date" = {
        type = "internal/date";
        time = "%I:%M %p";
        label = "%time%";
        format = "<label>";
        label-padding = 5;
      };
      "module/i3" = {
        type = "internal/i3";
        label-unfocused-foreground = "#${base03-hex}";
        label-unfocused-padding = 1;
        label-focused-padding = 1;
      };
    };
    script = ''
      polybar main &
    '';
  };

}
