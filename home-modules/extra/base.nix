{ config, pkgs, inputs, rootAbsolute, ... }:
let
  packagesMinimal = with pkgs; [
    # utilities
    cachix    # binary cache
    gc        # garbage collection script
    git       # version control
    gh        # github cli
    moreutils # more scripting tools
    nix-tree  # nix derivation graph browser
    pin       # easy nix package pinning
    ripgrep   # recursive grep
    screen    # terminal multiplexer
    wget      # download utility
    inputs.tx-calculator.packages.${pkgs.system}.tx-calculator

    # global aliases
    (aliasToPackage {
      hms = ''home-manager switch -L "$@"'';
      pai = ''${rootAbsolute}/pull-and-install.sh "$@"'';
    })
  ];

in
{
  xdg = {
    mimeApps.enable = true;
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
    sessionVariables = {
      GNUPGHOME = "${config.xdg.dataHome}/gnupg";
      XDG_CONFIG_HOME = config.xdg.configHome;
      XDG_CACHE_HOME = config.xdg.cacheHome;
      XDG_DATA_HOME = config.xdg.dataHome;
      XDG_STATE_HOME = config.xdg.stateHome;
    };
    packages = packagesMinimal;
  };

  systemd.user.startServices = true;
}
