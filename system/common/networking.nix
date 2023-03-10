{ config, pkgs, ... }:

{
  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 5000 2049 ];
    firewall.allowedUDPPorts = [ 5353 ];
    firewall.allowedUDPPortRanges = [ { from = 6001; to = 6101; } ];
  };
  services.tailscale.enable = true;
}
