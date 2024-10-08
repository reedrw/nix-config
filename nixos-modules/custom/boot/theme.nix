{ pkgs, lib, config, ... }:
let
  cfg = config.custom.boot.theme;

  distro-grub-themes = pkgs.fetchFromGitHub {
    owner = "AdisonCavani";
    repo = "distro-grub-themes";
    rev = "15b20532b0d443dbd118b179ac7b63cba9499511";
    hash = "sha256-OB8za/aaIcsnwGhOH2SR+2WeDi19Et67QuvK5geG9+o=";
  };
in
{
  options.custom.boot.theme.enable = lib.mkEnableOption "custom GRUB theme";

  config = lib.mkIf cfg.enable {
    boot.loader.grub = {
      theme = "${distro-grub-themes}/customize/nixos";
    };
  };
}
