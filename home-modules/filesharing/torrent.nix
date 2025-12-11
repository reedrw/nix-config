{ pkgs, lib, config, ... }:

{
  home.packages = [ pkgs.mktorrent ];
  systemd.user.services = config.lib.functions.mkSimpleService "qbittorrent"
    <| lib.getExe
    <| pkgs.mullvadExclude
    <| pkgs.qbittorrent-nox;
}
