{ pkgs, ... }:

{
  home.packages = [
    pkgs.eden
  ];

  custom.persistence.directories = [
    ".cache/eden"
    ".config/eden"
    ".local/share/eden"
  ];
}
