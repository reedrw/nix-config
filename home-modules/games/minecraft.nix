{ pkgs, ... }:

{
  stylix.targets = {
    prismlauncher.enable = true;
  };

  home.packages = with pkgs;[
    (mullvadExclude prismlauncher)
  ];
}
