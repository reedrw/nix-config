{ config, lib, ... }:
let
  cfg = config.custom.boot.efi;
in
{
  options.custom.boot.efi = {
    enable = lib.mkEnableOption "EFI boot support";

    # Which bootloader manages the ESP. "grub" for legacy hosts,
    # "systemd-boot" for the desktop (simpler, no GRUB graphics code).
    bootloader = lib.mkOption {
      type = lib.types.enum [ "grub" "systemd-boot" ];
      default = "grub";
      description = "Bootloader to install to the ESP";
    };
  };

  config = lib.mkIf cfg.enable {
    custom.boot.theme.enable = lib.mkIf (cfg.bootloader == "grub") true;
    boot.loader = {
      efi.canTouchEfiVariables = true;
    } // (if (cfg.bootloader == "grub") then {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
      };
    } else {
      systemd-boot.enable = true;
    });
  };
}
