{ config, lib, ... }:
let
  cfg = config.custom.boot.efi;
in
{
  options.custom.boot.efi.enable = lib.mkEnableOption "GRUB EFI support";

  config = lib.mkIf cfg.enable {
    custom.boot.theme.enable = true;
    boot.loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
