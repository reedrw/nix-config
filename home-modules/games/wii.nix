{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # dolphin-emu
    (mullvadExclude wheelwizard)
  ];

  custom.persistence.directories = [
    # ".config/dolphin-emu"
    # ".local/share/dolphin-emu"

    ".local/share/WiiCompiled"
    ".config/CT-MKWII"
  ];
}
