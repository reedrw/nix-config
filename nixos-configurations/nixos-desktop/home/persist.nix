{ config, osConfig, lib, inputs, ... }:
let
  homeDir = config.home.homeDirectory;
  json = builtins.fromJSON (builtins.readFile ../persist.json);
  # We only manage the files in home-manager due to this bug:
  # https://github.com/nix-community/impermanence/issues/130
  # Grab files that start with the home directory.
  homeFiles = builtins.filter (x: lib.hasPrefix homeDir x) json.files;
  homeDirs  = builtins.filter (x: lib.hasPrefix homeDir x) json.directories;
  # Remove the home directory from the file path.
  # Eg. [ /home/reed/.zsh_history /home/reed/.gitconfig ] -> [ /.zsh_history /.gitconfig ]
  files = builtins.map (v: builtins.substring (builtins.stringLength homeDir) 999999999 v) homeFiles;
  directories = builtins.map (v: builtins.substring (builtins.stringLength homeDir) 999999999 v) homeDirs;
in
{
  # imports = [
  #   inputs.impermanence.nixosModules.home-manager.impermanence
  # ];
  #
  # home.persistence."${osConfig.custom.persistDir}/${homeDir}" = {
  #   allowOther = true;
  #   files = [] ++ files;
  #   directories = [] ++ directories;
  # };
}
