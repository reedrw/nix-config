{ lib, config, inputs, ... }:
let
  cfg = config.custom.boot.theme;
in
{
  options.custom.boot.theme.enable = lib.mkEnableOption "custom GRUB theme";

  config = lib.mkIf cfg.enable {
    boot.loader.grub = {
      theme = "${inputs.distro-grub-themes}/customize/nixos";
    };
  };
}
