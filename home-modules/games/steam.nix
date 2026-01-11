{ lib, osConfig, ... }:

{
  config = lib.mkIf osConfig.programs.steam.enable {
    stylix.targets.steam.enable = true;

    custom.persistence.directories = [
      ".local/share/Steam"
      ".steam"
    ];
  };
}
