{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bottles
    ludusavi
  ];

  custom.persistence.directories = [
    ".local/share/bottles"
    ".config/ludusavi"
  ];
}
