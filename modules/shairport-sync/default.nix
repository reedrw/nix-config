{ config, lib, pkgs, ... }:
let
  # When https://github.com/NixOS/nixpkgs/pull/175860 hits unstable
  # remove below
  shairport-sync = pkgs.shairport-sync.overrideAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.glib ];
      configureFlags = old.configureFlags ++ [
        "--with-dbus-interface"
        "--with-mpris-interface"
      ];

      prePatch = ''
        sed 's/G_BUS_TYPE_SYSTEM/G_BUS_TYPE_SESSION/g' -i dbus-service.c
        sed 's/G_BUS_TYPE_SYSTEM/G_BUS_TYPE_SESSION/g' -i mpris-service.c
      '';
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
      Restart= "on-failure";
      Type = "simple";
    };
  };
}
