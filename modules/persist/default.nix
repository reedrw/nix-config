{ config, lib, inputs, ... }:
let
  json = builtins.fromJSON (builtins.readFile ../../system/nixos-desktop/persist.json);
  # We only manage the files in home-manager due to this bug:
  # https://github.com/nix-community/impermanence/issues/130
  # Grab files that start with the home directory.
  homeFiles = builtins.filter (x: lib.hasPrefix config.home.homeDirectory x) json.files;
  # Remove the home directory from the file path.
  # Eg. [ /home/reed/.zsh_history /home/reed/.gitconfig ] -> [ /.zsh_history /.gitconfig ]
  files = builtins.map (v: builtins.substring (builtins.stringLength config.home.homeDirectory) 999999999 v) homeFiles;
in
{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/home/reed" = {
    allowOther = true;
    files = [] ++ files;
  };

  home.file.".config/persist-path-manager/config.json".text = builtins.toJSON {
    activateCommand = "ldp";
    persistJson = "${config.home.homeDirectory}/.config/nixpkgs/system/nixos-desktop/persist.json";
    persistDir = "/persist";
    snapper = {
      enable = true;
      config = "persist";
    };
  };
}
