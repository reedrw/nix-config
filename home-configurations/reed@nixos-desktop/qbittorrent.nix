{ pkgs, lib, config, ... }:

{
  systemd.user.services = config.lib.functions.mkSimpleService "qbittorrent"
    <| lib.getExe
    <| pkgs.mullvadExclude
    <| pkgs.qbittorrent-nox;
}
