{ pkgs, util, ... }:
let
  tlaterpkgs = (util.importFlake ./sources).inputs.tlaterpkgs;
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
