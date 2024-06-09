{ config, pkgs, ... }:
let
  packagesMinimal = with pkgs; [
    # utilities
    cachix    # binary cache
    expect    # interactive automation
    git       # version control
    gh        # github cli
    moreutils # more scripting tools
    niv       # painless nix dependency management
    nix-tree  # nix derivation graph browser
    nq        # queue utility
    pin       # easy nix package pinning
    pm2       # process manager
    ripgrep   # recursive grep
    screen    # terminal multiplexer
    attic-client # self-hosted binary cache

    # global aliases
    (aliasToPackage {
      gc = ''
        if type -P lorri &> /dev/null; then
          lorri gc rm
        fi
        nix-collect-garbage "$@"
      '';
      hms = ''home-manager switch -L "$@"'';
      pai = ''~/.config/nixpkgs/pull-and-install.sh "$@"'';
    })
  ];

  packagesExtra = with pkgs; [
    # extra utilities
    bitwarden   # password manager
    gron        # greppable json
    jq          # json processor
    libnotify   # notification library
    libreoffice # free office suite
    ngrok       # port tunneling
    pavucontrol # volume control
    pipr        # interactive pipeline builder
    sshpass     # specify ssh password
    xclip       # x clipboard scripting
    xsel        # x clipbaord scripting
    (aliasToPackage {
      open = ''xdg-open "$@"'';
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
      EDITOR = "nvim";
      TERMINAL = "kitty";
      GNUPGHOME = "${config.xdg.dataHome}/gnupg";
      XDG_CONFIG_HOME = config.xdg.configHome;
      XDG_CACHE_HOME = config.xdg.cacheHome;
      XDG_DATA_HOME = config.xdg.dataHome;
      XDG_STATE_HOME = config.xdg.stateHome;
    };
    packages = packagesMinimal ++ packagesExtra;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}
