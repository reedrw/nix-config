{ pkgs, ... }:

{
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "docker"
      "input"
      "libvirtd"
      "networkmanager"
      "pipewire"
      "wheel"
    ];
    packages = with pkgs; [ home-manager ];
    shell = pkgs.zsh;
  };
}
