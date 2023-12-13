{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    (writeNixShellScript "nivpr" (builtins.readFile ./nivpr.sh))
    (writeNixShellScript "json2nix" (builtins.readFile ./json2nix.sh))
    inputs.hover.packages."${system}".default
  ];
}
