{ pkgs, ... }:

{
  home.packages = with pkgs; [
    duckstation
    pcsx2
  ];

  custom.persistence.directories = [
    ".config/duckstation"
    ".config/PCSX2"
  ];
}
