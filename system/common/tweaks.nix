{ config, pkgs, ... }:

{
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.udisks2.enable = true;

  systemd = let
    extraConfig = ''
      DefaultTimeoutStartSec=30s
      DefaultTimeoutStopSec=15s
    '';
  in {
    inherit extraConfig;
    user = {inherit extraConfig;};
  };
}
