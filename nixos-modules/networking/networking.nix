{ lib, ... }:
{
  networking.networkmanager.enable = true;

  # Don't block boot on network: NetworkManager-wait-online held
  # network-online.target for ~11s (the largest userspace boot cost).
  # Consumers (tailscaled, mullvad, cups-browsed) now start as soon as NM
  # itself is up instead of waiting for full connectivity.
  systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];

  custom.persistence.directories = [
    "/etc/NetworkManager/system-connections"
  ];
}
