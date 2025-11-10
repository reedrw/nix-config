{ lib, osConfig, ... }:

{
  home = {
    username = "reed";
    stateVersion = osConfig.system.stateVersion or lib.trivial.release;
    homeDirectory = "/home/reed";
  };
}
