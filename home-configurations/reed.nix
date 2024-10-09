{ ezModules, pkgs-unstable, ... }:

{
  imports = with ezModules; [
    common
  ];

  home.packages = [
    pkgs-unstable.meow
  ];

  home = {
    username = "reed";
    stateVersion = "20.09";
    homeDirectory = "/home/reed";
  };
}
