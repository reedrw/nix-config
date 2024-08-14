{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-${config.stylix.polarity}.yaml";
    image = ./wallpaper.png;
  };

  stylix.cursor = {
    package = pkgs.gnome.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };

  stylix.targets = {
    gtk.enable = true;
  };
}
