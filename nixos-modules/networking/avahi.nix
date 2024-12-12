{ config, lib, ... }:

{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  systemd.services.avahi-daemon = lib.mkIf config.services.mullvad-vpn.enable {
    after = [ "mullvad-daemon.service" ];
  };
}
