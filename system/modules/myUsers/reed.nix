{ pkgs, ... }:

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
    packages = with pkgs; [ home-manager ];
    shell = pkgs.zsh;
  };
}
