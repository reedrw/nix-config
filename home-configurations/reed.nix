{ ezModules, ... }:

{
  imports = with ezModules; [
    common
  ];
  home = {
    username = "reed";
    stateVersion = "20.09";
    homeDirectory = "/home/reed";
  };
}
