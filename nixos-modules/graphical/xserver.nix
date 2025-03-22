{ lib, pkgs, ... }:

{
  programs.dconf.enable = true;
  # programs.sway = {
  #   enable = true;
  #   package = pkgs.swayfx.overrideAttrs (oldAttrs: {
  #     passthru.providedSessions = [ "sway" ];
  #   });
  # };
  services.xserver = {
    enable = true;
    displayManager = {
      gdm = {
        wayland = false;
        enable = true;
      };
      session = [
        {
          manage = "desktop";
          name = "xsession";
          start = ''exec $HOME/.local/share/X11/xsession'';
        }
      ];
    };
  };
  systemd.services."lock-before-suspend" = {
    description = "Lock the screen before suspending";
    wantedBy = [ "suspend.target" ];
    before = [ "systemd-suspend.service" ];
    environment = {
      DISPLAY = ":0";
      #XAUTHORITY = "/var/run/lightdm/reed/xauthority";
    };
    serviceConfig = {
      Type = "forking";
      User = "reed";
      ExecStart = "${lib.getExe pkgs.lockProgram}";
    };
  };
}
