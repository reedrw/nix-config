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
    username = "spicypillow";
    homeDirectory = "/home/spicypillow";
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
