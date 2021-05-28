{ config, lib, pkgs, ... }:

{

  services.syncthing = {
    enable = true;
  };

  home.packages = with pkgs; [
    syncthing-gtk
  ];

}
