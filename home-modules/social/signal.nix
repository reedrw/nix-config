{ pkgs, ... }:

{
  home.packages = [
    pkgs.signal-desktop
  ];

  custom.persistence.directories = [
    ".config/Signal"
  ];
}
