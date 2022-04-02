{ config, lib, pkgs, ... }:
let
  shairport-sync = pkgs.shairport-sync.overrideAttrs (
    old: {
      configureFlags = old.configureFlags ++ [ "--with-metadata" ];
    }
  );
in
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
      ExecStart = "${shairport-sync}/bin/shairport-sync -v -o pa";
      ExecStop = "${pkgs.procps}/bin/pkill shairport-sync";
      Type = "simple";
    };
  };
}
