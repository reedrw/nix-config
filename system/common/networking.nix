{ config, pkgs, ... }:

{
  networking = {
    extraHosts = ''
      # Genshin logging servers (do not remove!)
      0.0.0.0 log-upload-os.mihoyo.com
      0.0.0.0 overseauspider.yuanshen.com

      # Optional Unity proxy/cdn servers
      0.0.0.0 prd-lender.cdp.internal.unity3d.com
      0.0.0.0 thind-prd-knob.data.ie.unity3d.com
      0.0.0.0 thind-gke-usc.prd.data.corp.unity3d.com
      0.0.0.0 cdp.cloud.unity3d.com
      0.0.0.0 remote-config-proxy-prd.uca.cloud.unity3d.com
    '';
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 5000 2049 ];
    firewall.allowedUDPPorts = [ 5353 ];
    firewall.allowedUDPPortRanges = [ { from = 6001; to = 6101; } ];
  };
}
