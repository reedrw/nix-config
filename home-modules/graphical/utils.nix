{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # extra utilities
    bitwarden-desktop  # password manager
    jq                 # json processor
  ];
}
