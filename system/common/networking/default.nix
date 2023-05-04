{ config, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [
      # shairport-sync
      5000
    ];
    firewall.allowedUDPPortRanges = [
      # shairport-sync
      { from = 6001; to = 6011; }
    ];
    hosts = {
      "0.0.0.0" = [
        "ffapple.com"
        "ppq.apple.com"
        "ocsp.apple.com"
        "ocsp2.apple.com"
        "www.ocsp.apple.com"
        "www.ocsp2.apple.com"
      ];
    };
    extraHosts = with sources; ''''
      + (builtins.readFile "${hosts}/hosts")
      + (builtins.readFile "${Lists}/ads.txt")
      + (builtins.readFile "${Lists}/tracking.txt")
      + (builtins.readFile "${Lists}/gambling.txt")
      + (builtins.readFile "${sources."Ultimate.Hosts.Blacklist"}/hosts/hosts0")
      + (builtins.readFile "${sources."Ultimate.Hosts.Blacklist"}/hosts/hosts1")
      + (builtins.readFile "${sources."Ultimate.Hosts.Blacklist"}/hosts/hosts2")
      + (builtins.readFile "${sources."Ultimate.Hosts.Blacklist"}/hosts/hosts3");
  };
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  systemd.services."mullvad-daemon".postStart = let
    mullvad = config.services.mullvad-vpn.package;
  in ''
    while ! ${mullvad}/bin/mullvad status >/dev/null; do sleep 1; done
    ${mullvad}/bin/mullvad lan set allow
    ${mullvad}/bin/mullvad auto-connect set on
  '';

  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  services.resolved.enable = true;
  services.tailscale.enable = true;

  systemd.services.tailscaled.serviceConfig.ExecStart = [
    ""
    ''${pkgs.mullvad}/bin/mullvad-exclude ${pkgs.tailscale}/bin/tailscaled \
      --state=/var/lib/tailscale/tailscaled.state \
      --socket=/run/tailscale/tailscaled.sock \
      --port=''${PORT} $FLAGS''
  ];

  networking.search = [ "tail3b7ba.ts.net" ];
  networking.nameservers = [
    "100.100.100.100"
    "1.1.1.1"
    "8.8.8.8"
  ];

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