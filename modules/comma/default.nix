{ config, lib, pkgs, ... }:
let

  indexCache = builtins.fetchurl {
    url = "https://s3.amazonaws.com/burkelibbey/nix-index-files";
    sha256 = "06p58f82wipd0a8wbc7j3l0p8iaxvdibgshmc9dbxkjf0hmln3kx";
  };

in
{

  home.packages = [ pkgs.nur.repos.reedrw.comma ];

  home.file.".cache/nix-index/files".source =
    if builtins.pathExists ./files
    then ./files else indexCache;

}
