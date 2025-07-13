{ pkgs, inputs, ... }:

{

  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ./command-not-found.nix
  ];

  home.packages = with pkgs; [ comma ];

  programs.nix-index = {
    symlinkToCacheHome = true;
    enable = false;
  };
}
