{ config, pkgs, lib, ... }:

{
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.udisks2.enable = true;

  security.sudo.extraConfig = ''
    # Prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl.
    Defaults use_pty
  '';

  services.dbus.implementation = "broker";

  systemd = let
    extraConfig = ''
      DefaultTimeoutStartSec=30s
      DefaultTimeoutStopSec=15s
    '';
  in {
    inherit extraConfig;
    user = { inherit extraConfig; };
  };

  system.activationScripts.diff = {
    supportsDryActivation = true;
    text = ''
      ${lib.getExe pkgs.nvd} \
        --color=always \
        --nix-bin-dir=${config.nix.package}/bin \
        diff /run/current-system "$systemConfig"
    '';
  };

  # Fix xdg-open in FHS sandbox
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = "*";
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  environment.systemPackages = with pkgs; [
    btdu
    ldp
    xdg-desktop-portal
  ];
}
