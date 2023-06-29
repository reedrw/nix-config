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
    files = [] ++ files;
  };

  home.file.".config/persist-path-manager/config.json".text = builtins.toJSON {
    activateCommand = "ldp";
    persistJson = "${config.home.homeDirectory}/.config/nixpkgs/system/nixos-desktop/persist.json";
    snapper = {
      enable = true;
      config = "persist";
    };
  };
}
