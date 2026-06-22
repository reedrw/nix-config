{ pkgs, ... }:

{
  wayland.windowManager.sway.config.output = {
    "DP-1" = { mode = "2650x1440@144Hz"; };
  };

  home.packages = with pkgs; [
    ddcutil
    (pkgs.aliasToPackage {
      brightness = ''ddcutil setvcp 10 "$@"'';
    })
  ];
}
