{ pkgs, ezModules, ... }:

{
  imports = [
    ezModules.styling
    ezModules.comma
    ezModules.zsh
    ezModules.nvim
    ezModules.nixpkgs
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
