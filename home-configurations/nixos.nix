{ ezModules, ezModules', ... }:

{
  imports = [
    {
      home = {
        username = "nixos";
        stateVersion = "25.05";
        homeDirectory = "/home/nixos";
      };
    }
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
    ezModules'.filesharing.jdownloader
  ];
}
