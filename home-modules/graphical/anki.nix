{ pkgs, ... }:

{
  programs.anki = {
    enable = true;
    package = pkgs.unstable.anki;
  };

  custom.persistence.directories = [
    ".local/share/Anki2"
  ];
}
