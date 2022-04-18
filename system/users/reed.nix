{ config, pkgs, ... }:

{
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "docker"
      "libvirtd"
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
