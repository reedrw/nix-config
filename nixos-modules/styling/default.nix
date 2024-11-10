{ pkgs, inputs, ... }:
let
  # schemes is from https://github.com/tinted-theming/schemes
  schemes = (import ./nix/sources.nix { }).schemes;
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
    base16Scheme = "${schemes}/base16/ayu-dark.yaml";
    image = ./wallpaper.png;
  };

  stylix.cursor = {
    package = pkgs.openzone-cursors;
    name = "OpenZone_Black";
    size = 24;
  };

  stylix.targets = {
    gtk.enable = true;
  };
}
