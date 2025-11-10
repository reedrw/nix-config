{ lib, pkgs, ezModules, osConfig, ... }:

{
  imports = [
    ezModules.core
  ];

  home = {
    username = "root";
    homeDirectory = "/root";
    stateVersion = osConfig.system.stateVersion or lib.trivial.release;
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      git
      ranger
    ];
  };
}
