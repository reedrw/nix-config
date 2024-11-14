{ pkgs, ... }:

{
  users.users.spicypillow = {
    isNormalUser = true;
    shell = pkgs.zsh;
  };
  nix.settings.trusted-users = [ "spicypillow" ];
}
