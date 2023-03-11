{ config, pkgs, ... }:

{
  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 5000 2049 ];
    firewall.allowedUDPPortRanges = [ { from = 6001; to = 6101; } ];
  };
  services = {
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
    tailscale.enable = true;
    resolved.enable = true;
  };

  systemd.services."mullvad-daemon".postStart = ''
    while ! ${pkgs.mullvad}/bin/mullvad status >/dev/null; do sleep 1; done
    ${pkgs.mullvad}/bin/mullvad lan set allow
    ${pkgs.mullvad}/bin/mullvad auto-connect set on
  '';

  systemd.services.tailscaled.serviceConfig.ExecStart = [
    ""
    "${pkgs.mullvad}/bin/mullvad-exclude ${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=\${PORT} $FLAGS"
  ];

  networking.nameservers = [
    "100.100.100.100"
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.search = [ "tail3b7ba.ts.net" ];
  networking.firewall.extraCommands =
    let
      ts = pkgs.writeText "tailscale.rules" ''
        table inet excludeTraffic {
          chain excludeOutgoing {
            type route hook output priority -100; policy accept;
            ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
          }
          chain excludeIncoming {
            type filter hook input priority -100; policy accept;
            ip saddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
          }
        }
      '';
    in
    ''
      ${pkgs.nftables}/bin/nft -f ${ts}
    '';
}
