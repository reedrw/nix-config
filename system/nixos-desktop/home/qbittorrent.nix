{ pkgs, lib, ... }:

{
  systemd.user.services = lib.simpleHMService "qbittorrent" (lib.getExe pkgs.qbittorrent-nox);
}
