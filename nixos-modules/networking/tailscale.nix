{
  services.resolved.enable = true;
  services.tailscale.enable = true;

  networking.search = [ "tail3b7ba.ts.net" ];

  networking.nftables = {
    enable = true;
    ruleset = ''
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
  };
}
