{ config, pkgs, ... }:
{
  systemd.user.services.shairport-sync = {
    Unit = {
      After = [ "network.target" "sound.target" ];
      Description = "Airplay audio player";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = with pkgs; {
      Environment = "PATH=${config.home.profileDirectory}/bin";
      ExecStart = "${binPath shairport-sync} -v -o pa";
      ExecStop = "${procps}/bin/pkill shairport-sync";
      Restart= "on-failure";
      Type = "simple";
    };
  };
}
