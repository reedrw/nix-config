{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };

  packages = with pkgs; [

    # utilities
    bitwarden
    cachix
    git
    github-cli
    htop
    libreoffice
    ngrok
    pavucontrol
    ripgrep
    xclip
    xsel

    # chat
    discord
    tdesktop

    # games
    polymc
    (
      steamPackages.steam-fhsenv.override {
        extraPkgs = pkgs: [ mangohud ];
      }
    )

  ];

  # `pai` anywhere to update computer
  globalAliases = {
    hms = "home-manager switch";
    ldp = "sh -c '(cd ~/.config/nixpkgs/; ./install.sh)'";
    pai = "~/.config/nixpkgs/pull-and-install.sh";
  };

  aliasToPackage = alias:
    (lib.mapAttrsToList
      (name: value: pkgs.writeShellScriptBin name value)
      alias
    )
  ;

  aliasPackages = aliasToPackage globalAliases;

in
{

  imports = builtins.map (x: ./modules + ("/" + x)) (builtins.attrNames (builtins.readDir ./modules));

  nixpkgs = {
    config = import ./config.nix;
    overlays = [ (import ./pkgs) ];
  };

  xdg = {
    userDirs = {
      enable = true;
      desktop = "\$HOME";
      documents = "\$HOME/files";
      download = "\$HOME/downloads";
      music = "\$HOME/music";
      pictures = "\$HOME/images";
      videos = "\$HOME/videos";
    };
  };

  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "reed";
    homeDirectory = "/home/reed";
    sessionVariables = {
      EDITOR = "nvim";
    };
    packages = packages ++ aliasPackages;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}
