{ lib, ezModules, osConfig, ... }:

{
  imports = [
    {
      home = {
        username = "nixos";
        stateVersion = osConfig.system.stateVersion or lib.trivial.release;
        homeDirectory = "/home/nixos";
      };
    }
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
  ];
}
