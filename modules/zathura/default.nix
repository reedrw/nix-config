{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [ zathura ];

  programs.zathura = {
    enable = true;
    options = {
      guioptions = "none";
    };
  };

}

