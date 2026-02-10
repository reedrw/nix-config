{ pkgs, ... }:

{
  home.packages = [ pkgs.balatro-mod-manager ];

  custom.persistence.directories = [ ".config/Balatro" ];
}
