{ config, lib, pkgs, ... }:
let
  packagesMinimal = with pkgs; [
    # utilities
    cachix     # binary cache
    expect     # interactive automation
    git        # version control
    github-cli # github from command line
    htop       # process monitor
    moreutils  # more scripting tools
    nom        # prettier nix output
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
      hms = "unbuffer home-manager switch |& nom";
      ldp = ''sh -c "(cd ~/.config/nixpkgs/; ./install.sh "$@")"'';
      pai = "~/.config/nixpkgs/pull-and-install.sh";
    })
  ];

  packagesExtra = with pkgs; [
    # extra utilities
    alejandra   # nix formatter
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
    yj          # yaml to json

    # more global aliases
    (aliasToPackage {
      json2nix = ''
        [[ -n "$1" ]] && json="$(readlink -f "$1")"
        [[ -p /dev/stdin ]] && json=/dev/stdin
        nix-instantiate -E --arg json "$json" '
          { json ? "" }:
          let
            v = builtins.fromJSON (builtins.readFile json);
          in
          builtins.trace v v
        ' &> /dev/stdout \
          | cut -f 2- -d ' ' \
          | alejandra -q
      '';
    })
  ];

  hostname = builtins.readFile /etc/hostname;

  full = builtins.pathExists (./system + "/${builtins.replaceStrings ["\n"] [".nix"] hostname}")
    || (builtins.getEnv "USER") == "runner";

in
{
  imports = if full
  then builtins.map (x: ./modules + "/${x}") (builtins.attrNames (builtins.readDir ./modules))
  else [
    ./modules/comma
    ./modules/nvim
    ./modules/ranger
    ./modules/styling
    ./modules/zsh
  ];

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
    packages = packagesMinimal ++ lib.optionals full packagesExtra;
  };

  systemd.user.startServices = true;

  home.stateVersion = "20.09";
}
