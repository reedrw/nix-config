{ pkgs, util, inputs, ... }:
let
  # schemes is from https://github.com/tinted-theming/schemes
  schemes = (util.importFlake ./sources).inputs.schemes;
in
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;
    autoEnable = false;
    homeManagerIntegration = {
      autoImport = false;
    };
    polarity = "dark";
    image = ./wallpaper.png;
    base16Scheme = "${schemes}/base16/ayu-dark.yaml";
  };

  stylix.icons = {
    enable = true;
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };

  stylix.fonts = {
    serif = {
      package = pkgs.cantarell-fonts;
      name = "Cantarell";
    };
    sansSerif = {
      package = pkgs.cantarell-fonts;
      name = "Cantarell";
    };
    monospace = {
      package = pkgs.hack-font;
      name = "Hack";
    };
    sizes.applications = 10;
  };

  stylix.cursor = {
    package = pkgs.openzone-cursors;
    name = "OpenZone_Black";
    size = 24;
  };

  stylix.targets = {
    gtk.enable = true;
    qt.enable = true;
  };
}
