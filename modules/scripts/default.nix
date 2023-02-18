{ config, lib, pkgs, ... }:
let
  scripts = with pkgs; symlinkJoin {
    name = "scripts";
    paths = [
      (writeShellApplication {
        name = "nivpr";
        runtimeInputs = [ curl jq niv ];
        text = (builtins.readFile ./nivpr.sh);
      })
    ];
  };
in
{
  home.packages = with pkgs; [ scripts ];
}
