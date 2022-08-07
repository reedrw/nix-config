{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [ pueue ];
  systemd.user.services.pueued = {
    Unit = {
      Description = "Pueue Daemon (user) - CLI process scheduler and manager";
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${pkgs.pueue}/bin/pueued -vvv";
      ExecReload = "${pkgs.pueue}/bin/pueued -vvv";
    };
  };
}
