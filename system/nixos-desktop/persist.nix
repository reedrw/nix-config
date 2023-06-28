{ ... }:
let
  json = (builtins.fromJSON (builtins.readFile ./persist.json));
in
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [] ++ json.directories;
  };
}
