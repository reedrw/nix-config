{ ... }:

{
  services.deluge = {
    enable = true;
    openFirewall = true;
    web.enable = true;
  };
  users.users.reed = {
    extraGroups = [ "deluge" ];
  };
}
