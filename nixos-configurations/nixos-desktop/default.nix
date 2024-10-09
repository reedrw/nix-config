{ ezModules, pkgs, ... }:
{
  imports = [
    ezModules.custom
    ezModules.common
    ezModules.myUsers
    ./configuration.nix
  ];

  home-manager.extraSpecialArgs = { inherit pkgs; };
}
