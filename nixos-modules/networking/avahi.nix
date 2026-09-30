{ config, lib, ... }:

{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    # Both flags must be set so nixpkgs provisions the dual-stack `mdns` NSS
    # module used in the nsswitch override below.
    nssmdns6 = true;
    # Don't announce (or answer on) virtual interfaces — otherwise the host
    # publishes its docker bridge / WAN IPv6 addresses under <hostname>.local
    # and other machines resolve the name to an unreachable address.
    denyInterfaces = [
      "lo"
      "docker*"
      "br-*"
      "veth*"
      "virbr*"
      "tailscale*"
      "wg-*"
      "vboxnet*"
      "vmnet*"
      "ve-*"
      "zt*"
    ];
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  # systemd-resolved must not run its own mDNS responder: it conflicts with
  # avahi on port 5353 and AAAA `.local` lookups time out (10s of retries
  # before resolved gives up). `.local` resolution goes through the NSS
  # modules (nss-mdns → avahi) instead.
  services.resolved.settings.Resolve.MulticastDNS = "no";

  # nss-mdns's `*_minimal` modules run a synchronous unicast `local. IN SOA`
  # check before answering every `.local` lookup. The check goes through
  # resolved to the router, which silently drops `.local` queries — costing
  # 2×5s of DNS retries per lookup. Use the full dual-stack `mdns` module
  # before `resolve` and whitelist `.local` in /etc/mdns.allow: a whitelisted
  # name is authoritative, so the SOA check is skipped entirely and lookups
  # go straight to avahi.
  environment.etc."mdns.allow".text = "local\n";

  system.nssDatabases.hosts = lib.mkForce [
    "mymachines"
    "mdns [NOTFOUND=return]"
    "resolve [!UNAVAIL=return]"
    "files"
    "myhostname"
    "dns"
  ];

  systemd.services.avahi-daemon = lib.mkIf config.services.mullvad-vpn.enable {
    after = [ "mullvad-daemon.service" ];
  };
}
