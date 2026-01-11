{ pkgs, ... }:

{
  home.packages = [ pkgs.filezilla ];

  custom.persistence.directories = [
    ".config/filezilla"
  ];
}
