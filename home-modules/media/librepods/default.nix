{ pkgs, lib, config, ... }:

{
  systemd.user.services = lib.mergeAttrsList [
    (config.lib.functions.mkSimpleService "airpods-battery" "${
      pkgs.writeNixShellScript "airpods-battery" (builtins.readFile ./airpods-battery.sh)
    }/bin/airpods-battery")
    {
      airpods-watcher = {
        Unit = {
          Description = "Start/stop librepods based on AirPods connection state";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.writeNixShellScript "airpods-watcher" (
            builtins.readFile ./airpods-watcher.sh
          )}/bin/airpods-watcher";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      librepods = {
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
    }
  ];
}
