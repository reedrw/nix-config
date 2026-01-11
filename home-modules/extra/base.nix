{ config, pkgs, inputs, rootAbsolute, ... }:
let
  packagesMinimal = with pkgs; [
    # utilities
    gc        # garbage collection script
    jq        # json processor
    moreutils # more scripting tools
    pin       # easy nix package pinning
    rar       # rar unzipper
    ripgrep   # recursive grep
    screen    # terminal multiplexer
    wget      # download utility
    progress  # progress viewer
    p7zip     # 7z unzipper
    inputs.tx-calculator.packages.${pkgs.stdenv.hostPlatform.system}.tx-calculator

    # global aliases
    (aliasToPackage {
      hms = ''home-manager switch -L "$@"'';
      pai = ''${rootAbsolute}/pull-and-install.sh "$@"'';
    })
  ];

in
{
  imports = [
    {
      programs.home-manager.enable = true;

      custom.persistence.directories = [
        ".local/share/home-manager"
      ];
    }

    {
      home.packages = [ pkgs.cachix ];

      custom.persistence.directories = [
        ".config/cachix"
      ];
    }

    {
      custom.persistence.directories = [
        ".cache/pre-commit"
      ];
    }
  ];

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

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    sessionVariables = {
      SCREENDIR = "${config.xdg.dataHome}/screen";
      _JAVA_OPTIONS="-Djava.util.prefs.userRoot=${config.xdg.dataHome}/java";
      XDG_CONFIG_HOME = config.xdg.configHome;
      XDG_CACHE_HOME = config.xdg.cacheHome;
      XDG_DATA_HOME = config.xdg.dataHome;
      XDG_STATE_HOME = config.xdg.stateHome;
    };
    packages = packagesMinimal;
  };

  custom.persistence.directories = [
    "downloads"
    "files"
    "games"
    "images"
    "music"
    "videos"
  ];

  systemd.user.startServices = true;
}
