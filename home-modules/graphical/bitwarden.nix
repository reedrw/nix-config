{ pkgs-unstable, ... }:

{

  home.packages = [
    pkgs-unstable.bitwarden-desktop
  ];

  custom.persistence.directories = [
    ".config/Bitwarden"
  ];
}
