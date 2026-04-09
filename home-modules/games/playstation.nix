{ pkgs, ... }:

{
  home.packages = with pkgs; [
    pcsx2
  ];

  custom.persistence.directories = [
    ".config/PCSX2"
  ];
}
