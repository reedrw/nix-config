{ pkgs, config, lib, ... }:

{
  home.packages = with pkgs; [
    (mullvadExclude prismlauncher)
  ];

  home.activation.themePrismIcons = let
    theme =
      if config.stylix.polarity == "light"
      then "flat"
      else "flat_white";
  in config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe pkgs.crudini} --set "${config.xdg.dataHome}/PrismLauncher/prismlauncher.cfg" General IconTheme "${theme}"
  '';
}
