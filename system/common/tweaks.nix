{ config, pkgs, ... }:

{
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.udisks2.enable = true;

  security.sudo.extraConfig = ''
    # Prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl.
    Defaults use_pty
  '';

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
