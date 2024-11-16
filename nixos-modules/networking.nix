{ config, pkgs, lib, ... }:

{
  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [
      # shairport-sync
      5000

      # qbittorrent
      43173
    ];
    firewall.allowedUDPPortRanges = [
      # shairport-sync
      { from = 6001; to = 6011; }
    ];
  };
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;
  };

  # This is how I access mullvad in Firefox, allowing me to use the
  # foxyproxy extension to switch between mullvad and my normal
  # connection and set per-domain rules.
  services.autossh.sessions = let
    mullvadEnabled = config.services.mullvad-vpn.enable;
  in (lib.optionals mullvadEnabled [{
    extraArguments = "-D 1337 -nNT localhost";
    name = "mullvad-socks-proxy";
    user = "reed";
  }]);

  systemd.services.mullvad-daemon = {
    after = [
      "nix-daemon.service"
      "tailscaled.service"
    ];
    preStart = ''
      sleep 5
    '';
    postStart = let
      mullvad = config.services.mullvad-vpn.package;
    in ''
      while ! ${mullvad}/bin/mullvad status >/dev/null; do sleep 1; done
      ${mullvad}/bin/mullvad lan set allow
      ${mullvad}/bin/mullvad auto-connect set on
      ${mullvad}/bin/mullvad split-tunnel add "$(${pkgs.procps}/bin/pidof nix-daemon)"
      ${mullvad}/bin/mullvad split-tunnel add "$(${pkgs.procps}/bin/pidof tailscaled)"
    '';
  };

  systemd.services.avahi-daemon = lib.mkIf config.services.mullvad-vpn.enable {
    after = [ "mullvad-daemon.service" ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

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
