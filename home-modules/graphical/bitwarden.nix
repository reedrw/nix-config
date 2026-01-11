{ pkgs, ... }:

{
  home.packages = [
    pkgs.bitwarden-desktop
  ];

  custom.persistence.directories = [
    ".config/Bitwarden"
  ];
}
