{ config, pkgs, lib, inputs, ... }:

{
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.udisks2.enable = true;

  security.sudo.extraConfig = ''
    # Prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl.
    Defaults use_pty
  '';

  services.dbus.implementation = "broker";

  # set console colors
  console.colors = with inputs.nix-colors.colorSchemes.horizon-terminal-dark.palette; let
    black   = base00;
    blue    = base0D;
    cyan    = base0C;
    green   = base0B;
    grey    = base03;
    magenta = base0E;
    red     = base08;
    white   = base05;
    yellow  = base0A;
  in [ black red green yellow blue magenta cyan white
        grey red green yellow blue magenta cyan white ];

  systemd = let
    extraConfig = ''
      DefaultTimeoutStartSec=30s
      DefaultTimeoutStopSec=15s
      DefaultLimitNOFILE=2048:1048576
    '';
  in {
    inherit extraConfig;
    user = { inherit extraConfig; };
    services."lock-before-suspend" = {
      description = "Lock the screen before suspending";
      wantedBy = [ "suspend.target" ];
      before = [ "systemd-suspend.service" ];
      environment = {
        DISPLAY = ":0";
        XAUTHORITY = "/var/run/lightdm/reed/xauthority";
      };
      serviceConfig = {
        Type = "forking";
        User = "reed";
        ExecStart = "${lib.getExe pkgs.lockProgram}";
      };
    };
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
