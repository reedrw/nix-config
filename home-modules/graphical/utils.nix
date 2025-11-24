{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # extra utilities
    bitwarden   # password manager
    jq          # json processor
    obs-studio  # screen recording
  ];
}
