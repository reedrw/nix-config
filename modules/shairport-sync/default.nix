{ config, lib, pkgs, ... }:

{
  systemd.user.services.shairport-sync = {
    Unit = {
      After = [ "network.target" "sound.target" ];
      Description = "Airplay audio player";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Environment = "PATH=${config.home.profileDirectory}/bin";
      ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -v -o pa";
      ExecStop = "${pkgs.procps}/bin/pkill shairport-sync";
      Type = "simple";
    };
  };
}
