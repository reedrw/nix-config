{ lib, config, ... }:
let
  cfg = config.custom.boot.bios;
in
{
  options.custom.boot.bios = {
    enable = lib.mkEnableOption "Enable BIOS boot loader";
  };

  config = lib.mkIf cfg.enable {
    boot.loader.grub = {
      enable = true;
      version = 2;
    };
  };
}
