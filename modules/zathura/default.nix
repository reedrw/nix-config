{ config, lib, pkgs, ... }:

{

  programs.zathura = {
    enable = true;
    options = {
      guioptions = "none";
    };
  };

}
