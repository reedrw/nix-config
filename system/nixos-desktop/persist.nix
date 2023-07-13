{ pkgs, ... }:
let
  json = (builtins.fromJSON (builtins.readFile ./persist.json));
in
{
  programs.fuse.userAllowOther = true;

  environment.systemPackages = [
    (import ./persist-path-manager { inherit pkgs; })
  ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [] ++ json.directories;
  };
}
