{ pkgs, ... }:
let
  scripts = with pkgs; symlinkJoin {
    name = "scripts";
    paths = [
      (writeShellApplication {
        name = "nivpr";
        runtimeInputs = [ curl jq niv ];
        text = (builtins.readFile ./nivpr.sh);
      })
      (writeShellApplication {
        name = "json2nix";
        runtimeInputs = [ alejandra ];
        text = (builtins.readFile ./json2nix.sh);
      })
    ];
  };
in
{
  home.packages = [ scripts ];
}
