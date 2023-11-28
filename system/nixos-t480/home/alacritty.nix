{ pkgs, ... }:

{
  home.packages = [ pkgs.curie ];
  programs.alacritty.settings = {
    font = let family = "curie"; in {
      size = 7;
      normal = {
        inherit family;
        style = "Medium";
      };
      bold = {
        inherit family;
        style = "Bold";
      };
      italic = {
        inherit family;
        style = "Italic";
      };
      bold_italic = {
        inherit family;
        style = "Bold";
      };
    };
  };
}
