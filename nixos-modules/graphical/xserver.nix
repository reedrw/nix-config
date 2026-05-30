{ lib, pkgs, config, ... }:

{
  # https://github.com/NixOS/nixpkgs/pull/523948
  # propagate display-manager.service environment into GDM PAM session
  security.pam.services.gdm-launch-environment.rules.session.env-greeter = {
    order = config.security.pam.services.gdm-launch-environment.rules.session.env.order + 50;
    control = "required";
    modulePath = "${config.security.pam.package}/lib/security/pam_env.so";
    settings =
      let
        env = config.services.displayManager.generic.environment;
      in
      {
        # OVERRIDE= (not DEFAULT=) is required: an earlier pam_env rule reads
        # /etc/pam/environment and pre-populates PATH/XDG_DATA_DIRS, so DEFAULT=
        # would be a no-op for those vars.
        conffile = pkgs.writeText "gdm-launch-environment-env-conf" (
          ''
            PATH                    OVERRIDE="''${PATH}:${pkgs.gnome-session}/bin"
            XDG_DATA_DIRS           OVERRIDE="''${XDG_DATA_DIRS}:${env.XDG_DATA_DIRS}"
            GDM_X_SERVER_EXTRA_ARGS OVERRIDE="${env.GDM_X_SERVER_EXTRA_ARGS}"
          ''
          + lib.optionalString (env ? GDM_X_SESSION_WRAPPER) ''
            GDM_X_SESSION_WRAPPER   OVERRIDE="${env.GDM_X_SESSION_WRAPPER}"
          ''
        );
        readenv = 0;
      };
  };
  programs.dconf.enable = true;
  # programs.sway = {
  #   enable = true;
  #   package = pkgs.swayfx.overrideAttrs (oldAttrs: {
  #     passthru.providedSessions = [ "sway" ];
  #   });
  # };
  services.displayManager = {
    defaultSession = "xsession";
    gdm = {
      enable = true;
    };
  };

  services.xserver = {
    enable = true;
    displayManager.session = lib.optionals (!config.services.desktopManager.gnome.enable) [
      {
        manage = "desktop";
        name = "xsession";
        start = ''exec $HOME/.local/share/X11/xsession'';
      }
    ];
  };

  systemd.services."lock-before-suspend" = {
    description = "Lock the screen before suspending";
    wantedBy = [ "suspend.target" ];
    before = [ "systemd-suspend.service" ];
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "/run/user/1000/gdm/Xauthority";
    };
    serviceConfig = {
      Type = "forking";
      User = "reed";
      ExecStart = "${lib.getExe pkgs.lockProgram}";
    };
  };
}
