{ pkgs, lib, config, ... }:

{
  systemd.user.services = config.lib.custom.mkSimpleService "qbittorrent" (lib.getExe pkgs.qbittorrent-nox);
}
