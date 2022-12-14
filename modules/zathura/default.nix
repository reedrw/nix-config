{ config, lib, pkgs, ... }:

{

  programs.zathura = {
    enable = true;
    package = pkgs.fromBranch.stable.zathura;
    options = {
      guioptions = "none";
    };
  };

}
