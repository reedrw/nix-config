{ config, pkgs, ... }:

{
  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };
}
