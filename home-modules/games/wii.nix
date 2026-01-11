{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dolphin-emu
    (mullvadExclude wheel-wizard)
  ];

  custom.persistence.directories = [
    ".config/dolphin-emu"
    ".local/share/dolphin-emu"

    ".config/CT-MKWII"
  ];
}
