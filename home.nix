{ config, lib, pkgs, ... }:
let
  sources = import ./functions/sources.nix { sourcesFile = ./sources.json; };

  packages = with pkgs; [

    # utilities
    anki
    bitwarden
    bitwarden-cli
    cachix
    droidcam
    git
    github-cli
    htop
    libreoffice
    ngrok
    noisetorch
    pavucontrol
    ripgrep
    virt-manager

    # chat
    discord
    element-desktop
    tdesktop
    teams

    # games
    multimc
    r2mod_cli
    steam

    # fonts
    nur.repos.reedrw.artwiz-lemon
    scientifica

  ];

  globalAliases = {
    hms = "${pkgs.expect}/bin/unbuffer home-manager switch";
    ldp = "${pkgs.expect}/bin/unbuffer sh -c '(cd ~/.config/nixpkgs/; ./install.sh)'";
    pai = "${pkgs.expect}/bin/unbuffer ~/.config/nixpkgs/pull-and-install.sh";
  };

  aliasToPackage = alias:
    (lib.mapAttrsToList
      (name: value: pkgs.writeShellScriptBin name value)
      alias
    )
  ;

  aliasPackages = aliasToPackage globalAliases;

  config = builtins.toFile "config.nix" ''
    {
      allowUnfree = true;
      allowBroken = true;
      packageOverrides = pkgs: {
        nur = import ${sources.NUR} {
          inherit pkgs;
        };
      };
    }
  '';

in
{

  imports = builtins.map (x: ./modules + ("/" + x)) (builtins.attrNames (builtins.readDir ./modules));

  nixpkgs = {
    config = import "${config}";
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
    configFile = {
      "nixpkgs/config.nix".source = "${config}";
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
