{ pkgs, ... }:
{
  home.packages = (with pkgs; [
    azahar # Arctic Base
  ]) ++ (with pkgs.nur.repos.ihaveamac; [
    ctrtool
    cxitool
    makerom
  ]);

  custom.persistence.directories = [
    ".config/azahar-emu"
    ".local/share/azahar-emu"
  ];
}
