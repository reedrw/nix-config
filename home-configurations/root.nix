{ pkgs, ezModules, ... }:

{
  imports = [
    ezModules.core
  ];

  home = {
    username = "root";
    homeDirectory = "/root";
    stateVersion = "22.05";
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      git
      ranger
    ];
  };
}
