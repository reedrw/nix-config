{ pkgs, ... }:

{
  home.packages = [
    pkgs.eden
  ];

  custom.persistence.directories = [
    ".local/share/eden"
  ];
}
