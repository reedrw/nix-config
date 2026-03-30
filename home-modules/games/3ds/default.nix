{ pkgs, util, ... }:
let
  tlaterpkgs = (util.importFlake ./sources).inputs.tlaterpkgs;
in
{
  home.packages = (with pkgs; [
    azahar # Arctic Base
  ]) ++ (with pkgs.nur.repos.ihaveamac; [
    ctrtool
    cxitool
    makerom
  ]) ++ (with tlaterpkgs.packages."${pkgs.stdenv.hostPlatform.system}"; [
    servefiles
  ]);

  custom.persistence.directories = [
    ".config/azahar-emu"
    ".local/share/azahar-emu"
  ];
}
