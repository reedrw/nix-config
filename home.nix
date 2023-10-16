{ pkgs, ... }:
let
  packagesMinimal = with pkgs; [
    # utilities
    cachix     # binary cache
    expect     # interactive automation
    git        # version control
    github-cli # github from command line
    htop       # process monitor
    moreutils  # more scripting tools
    nix-tree   # nix derivation graph browser
    niv        # painless nix dependency management
    nq         # queue utility
    pm2        # process manager
    ripgrep    # recursive grep
    screen     # terminal multiplexer

    # global aliases
    (aliasToPackage {
      gc = ''
        if type -P lorri &> /dev/null; then
          lorri gc rm
        fi
        nix-collect-garbage "$@"
      '';
      hms = "home-manager switch -L";
      ldp = ''~/.config/nixpkgs/install.sh "$@"'';
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
  ];

in
{
  imports = builtins.map (x: ./modules + "/${x}") (builtins.attrNames (builtins.readDir ./modules));

  nixpkgs = {
    overlays = [ (import ./pkgs) ];
    config = import ./config.nix;
  };

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
      TERMINAL = "alacritty";
    };
    packages = packagesMinimal ++ packagesExtra;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}
