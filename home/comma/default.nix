{ pkgs, inputs, ... }:

{

  imports = [ inputs.nix-index-database.hmModules.nix-index ];

  home.packages = with pkgs; [ comma ];

  programs.nix-index = {
    symlinkToCacheHome = true;
    enable = false;
  };
}
