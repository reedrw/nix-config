{ pkgs, ... }:

{
  services.easyeffects.enable = true;

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
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = [
    pkgs.pwvucontrol
  ];

  custom.persistence.directories = [
    ".config/easyeffects"
    ".local/state/wireplumber"
  ];
}
