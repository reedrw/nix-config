{ pkgs, ... }:

{
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "pipewire"
      "docker"
      "input"
      "libvirtd"
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [ home-manager ];
    shell = pkgs.zsh;
  };
}
