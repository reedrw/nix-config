{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lutris
  ];

  custom.persistence.directories = [
    ".local/share/lutris"
    ".local/share/umu"
  ];
}
