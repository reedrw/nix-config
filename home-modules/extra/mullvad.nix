{ osConfig, lib, ... }:

{
  config = lib.mkIf osConfig.services.mullvad-vpn.enable {
    custom.persistence.directories = [
      ".config/Mullvad VPN"
    ];
  };
}
