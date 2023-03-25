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

  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];
}
