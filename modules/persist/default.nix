{ inputs, ... }:

{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/home/reed" = {
    allowOther = true;
    files = [
      ".cache/rofi-2.sshcache"
      ".cache/rofi-3.runcache"
      ".cache/rofi3.druncache"
      ".gitconfig"
      ".zsh_history"

      # symlinks for xdg dirs
      "downloads"
      "files"
      "games"
      "images"
      "music"
      "persist"
      "videos"
    ];
  };
}
