{
  networking.firewall = {
    allowedTCPPorts = [
      # SSDP/UPnP
      1900

      # shairport-sync
      5000

      # qbittorrent
      43173
    ];
    allowedUDPPorts = [
      # SSDP/UPnP
      1900
    ];
    allowedUDPPortRanges = [
      # shairport-sync
      { from = 6001; to = 6011; }
    ];
  };
}
