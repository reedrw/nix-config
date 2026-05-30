{ pkgs, util, ... }:
let
  sources = (util.importFlake ./sources).inputs;
in
{
  imports = [ sources.run0-sudo-shim.nixosModules.default ];

  nixpkgs.overlays = [ sources.run0-sudo-shim.overlays.default ];

  security.run0-sudo-shim = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "sudo";
      paths = [ pkgs.run0-sudo-shim ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/sudo --add-flags "--run0-extra-arg=--background="
      '';
    };
  };

  systemd.user.services.authentication-agent = {
    description = "authentication-agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.mate-polkit}/libexec/polkit-mate-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  security.polkit.persistentAuthentication = true;
}
