{ config, pkgs, lib, ... }:
let
  nameservers = lib.lists.remove "100.100.100.100" config.networking.nameservers;
in
{
  networking = {
    networkmanager = {
      enable = true;
      insertNameservers = nameservers;
    };
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
  };
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;
  };

  services.autossh.sessions = let
    mkSession = extraArguments: name: user: {
      inherit extraArguments name user;
    };
  in [
    (mkSession "-D 1337 -nNT localhost" "mullvad-socks-proxy" "reed")
  ];

  systemd.services."mullvad-daemon".postStart = let
    mullvad = config.services.mullvad-vpn.package;
    dnsServers = builtins.concatStringsSep " " nameservers;
  in ''
    while ! ${mullvad}/bin/mullvad status >/dev/null; do sleep 1; done
    ${mullvad}/bin/mullvad lan set allow
    ${mullvad}/bin/mullvad auto-connect set on
    ${mullvad}/bin/mullvad dns set custom ${dnsServers}
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

  systemd.services.tailscaled = {
    after = [ "mullvad-daemon.service" ];
    serviceConfig = {
      ExecStart = with pkgs; [
        ""
        ''${mullvadExclude tailscale}/bin/tailscaled \
          --state=/var/lib/tailscale/tailscaled.state \
          --socket=/run/tailscale/tailscaled.sock \
          --port=''${PORT} $FLAGS''
      ];
    };
  };

  networking.search = [ "tail3b7ba.ts.net" ];
  networking.nameservers = [
    "100.100.100.100"
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.firewall.extraCommands =
    let
      ts = builtins.toFile "tailscale.rules" ''
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
