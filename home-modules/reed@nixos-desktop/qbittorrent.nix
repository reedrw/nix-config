{ pkgs, lib, config, ... }:

{
  systemd.user.services = config.lib.functions.mkSimpleService "qbittorrent" <| lib.getExe pkgs.qbittorrent-nox;

  home.packages = with pkgs; [
    mktorrent
  ];
}
