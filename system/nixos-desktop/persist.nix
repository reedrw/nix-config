{ inputs, outputs, config, lib, pkgs, ... }:
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/mullvad-vpn"
      "/etc/nixos"
      "/etc/ssh"

      "/var/db/sudo"

      "/var/lib/NetworkManager"
      "/var/lib/blueman"
      "/var/lib/bluetooth"
      "/var/lib/deluge"
      "/var/lib/docker"
      "/var/lib/jellyfin"
      "/var/lib/libvirt"
      "/var/lib/systemd"
      "/var/lib/tailscale"
    ];
  };
}
