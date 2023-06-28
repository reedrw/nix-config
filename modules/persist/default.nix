{ config, lib, inputs, ... }:
let
  json = builtins.fromJSON (builtins.readFile ../../system/nixos-desktop/persist.json);
  files = builtins.map (v: builtins.substring (builtins.stringLength config.home.homeDirectory) 999999999 v) (builtins.filter (x: lib.hasPrefix config.home.homeDirectory x) json.files);
in
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
    ] ++ files;
  };
}
