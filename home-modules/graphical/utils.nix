{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # extra utilities
    bitwarden   # password manager
    gron        # greppable json
    jq          # json processor
    libnotify   # notification library
    libreoffice # free office suite
    ngrok       # port tunneling
    pipr        # interactive pipeline builder
    sshpass     # specify ssh password
    (aliasToPackage {
      open = ''xdg-open "$@"'';
    })
  ];
}
