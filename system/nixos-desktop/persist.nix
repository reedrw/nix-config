{ pkgs, ... }:
let
  json = (builtins.fromJSON (builtins.readFile ./persist.json));
in
{
  programs.fuse.userAllowOther = true;
  environment.systemPackages = with pkgs; [
    (writeNixShellScript "persist" (builtins.readFile ./persist.sh))
  ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [] ++ json.directories;
  };
}
