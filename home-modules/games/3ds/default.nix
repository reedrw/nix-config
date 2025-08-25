{ pkgs, ... }:
let
  tlaterpkgs = (pkgs.importFlake ./sources).inputs.tlaterpkgs;
in
{
  home.packages = (with pkgs.nur.repos.ihaveamac; [
    ctrtool
    cxitool
    makerom
  ]) ++ (with tlaterpkgs.packages."${pkgs.system}"; [
    servefiles
  ]);
}
