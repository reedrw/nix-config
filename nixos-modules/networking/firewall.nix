{
  networking.firewall = {
    allowedTCPPorts = [
      # shairport-sync
      5000

      # qbittorrent
      43173
    ];
    allowedUDPPortRanges = [
      # shairport-sync
      { from = 6001; to = 6011; }
    ];
  };
}
