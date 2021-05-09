{ config, lib, pkgs, ... }:
let

  indexCache = builtins.fetchurl (lib.importJSON ./source.json);

in
{

  home.packages = [ pkgs.nur.repos.reedrw.comma ];

  home.file.".cache/nix-index/files".source = indexCache;

}
