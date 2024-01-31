{ inputs, outputs, pkgs, lib, hm, ... }:

lib.optionalAttrs hm {
  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users.root = {

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

      # imports
      imports = [
        # Dark mode when running apps in sudo
        ../../../home/styling
        # Nix-index cache and comma in sudo
        ../../../home/comma
        # Zsh
        ../../../home/zsh
        # Neovim
        ../../../home/nvim
      ];
    };
  };
}
