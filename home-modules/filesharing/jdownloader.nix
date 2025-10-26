{ pkgs, ... }:

{
  home.packages = [
    (pkgs.jdownloader.override {
      darkTheme = true;
    })
  ];
}
