{ pkgs, lib, ... }:

{
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
    (mkSimpleService "qbittorrent" "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox")
  ];
}
