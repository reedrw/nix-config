{ pkgs, ... }:

{
  users.users.reed = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "docker"
      "input"
      "librepods"
      "libvirtd"
      "networkmanager"
      "pipewire"
      "wheel"
    ];
    packages = with pkgs; [ home-manager ];
    shell = pkgs.zsh;
  };
}
