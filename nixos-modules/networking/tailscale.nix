{
  services.resolved.enable = true;
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  networking.search = [ "tail3b7ba.ts.net" ];

  custom.persistence.directories = [
    "/var/lib/tailscale"
  ];
}
