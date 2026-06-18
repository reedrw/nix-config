{ pkgs, ... }:

{
  systemd.user.services.librepods = {
    Unit = {
      Description = "LibrePods AirPods daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/wrappers/bin/librepods";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.user.services.airpods-watcher = {
    Unit = {
      Description = "Start/stop librepods based on AirPods connection state";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellApplication {
        name = "airpods-watcher";
        runtimeInputs = [ pkgs.bluez pkgs.easyeffects ];
        text = builtins.readFile ./airpods-watcher.sh;
      }}/bin/airpods-watcher";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
