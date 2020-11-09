{ config, lib, pkgs, ... }:

{

  home.packages = [ pkgs.nur.repos.reedrw.comma ];

  home.file.".cache/nix-index/files".source = ./files;

}
