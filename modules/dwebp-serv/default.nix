{ pkgs, ... }:
let
  dwebp-serv = pkgs.writeNixShellScript "dwebp-serv" (builtins.readFile ./dwebp-serv.sh);
in
{
  systemd.user.services = {
    dwebp-serv = {
      Unit = {
        Description = "dwebp-serv";
        After = [ "graphical.target" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = with pkgs; {
        ExecStart = "${binPath dwebp-serv}";
        Restart = "on-failure";
        RestartSec = 5;
        Type = "simple";
      };

    };
  };
}
