{ pkgs, ... }:

{
  xsession.windowManager.i3.config.startup = let
    alwaysRun = [];
    run = [
      "xrandr --output DisplayPort-0 --mode 1920x1080 --rate 144"
      "xrandr --output DisplayPort-1 --mode 1920x1080 --rate 144"
      "xrandr --output DisplayPort-2 --mode 1920x1080 --rate 144"
    ];
  in map ( command: {
    inherit command;
    always = true;
    notification = false;
  }) alwaysRun ++ map ( command: {
    inherit command;
    notification = false;
  }) run;

  # systemd.user.services = let
  #   mkSimpleService = name: ExecStart: {
  #     ${name} = {
  #       Unit = {
  #         Description = "${name}";
  #         After = [ "graphical.target" ];
  #       };
  #       Install = {
  #         WantedBy = [ "default.target" ];
  #       };
  #       Service = {
  #         inherit ExecStart;
  #         Restart = "on-failure";
  #         RestartSec = 5;
  #         Type = "simple";
  #       };
  #     };
  #   };
  # in mkSimpleService "x11vnc" "${pkgs.writeNixShellScript "x11vnc" (builtins.readFile ./scripts/x11vnc.sh)}/bin/x11vnc";
}
