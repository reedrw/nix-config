{
  networking.firewall = {
    checkReversePath = "loose";
    allowedTCPPorts = [
      # SSDP/UPnP
      1900

      # HTTP
      8080

      # shairport-sync
      5000

      # qbittorrent
      43173
    ];
    allowedUDPPorts = [
      # SSDP/UPnP
      1900

      # qbittorrent
      43173
    ];
    allowedUDPPortRanges = [
      # shairport-sync
      { from = 6001; to = 6011; }
    ];
  };

  networking.nftables = {
    enable = true;
    tables.vpnExcludeTraffic = {
      enable = true;
      family = "inet";
      content = ''
        chain allowIncoming {
          type filter hook input priority -100; policy accept;
          tcp dport { 43173 } ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
        }
        chain allowOutgoing {
          type route hook output priority -100; policy accept;
          tcp sport { 43173 } ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
        }
        chain excludeOutgoing {
          type route hook output priority -100; policy accept;
          ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
        }
        chain excludeIncoming {
          type filter hook input priority -100; policy accept;
          ip saddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
        }
      '';
    };
  };
}
