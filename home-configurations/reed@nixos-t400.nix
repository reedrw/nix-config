{ ezModules, ... }:

{
  imports = [
    ./reed.nix
    ezModules.base
    ezModules.comma
    ezModules.functions
    ezModules.htop
    ezModules.nixpkgs
    ezModules.nvim
    ezModules.ranger
    ezModules.styling
    ezModules.zsh
  ];
}
