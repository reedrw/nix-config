{ lib, config, ... }:
let
  homeDir = "/home/reed";
  json = (builtins.fromJSON (builtins.readFile ./persist.json));

  # remove directories that start with the home directory
  directories = builtins.filter (dir: !lib.hasPrefix homeDir dir) json.directories;
in
{
  programs.fuse.userAllowOther = true;

  environment.persistence."${config.custom.persistDir}" = {
    hideMounts = true;
    directories = [] ++ directories;
  };
}
