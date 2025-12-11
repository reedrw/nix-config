{ config, lib, util, ... }:
let
  cfg = config.custom.boot.keyfile-unlock;
in
{
  options.custom.boot.keyfile-unlock = {
    enable = lib.mkEnableOption "enable keyfile unlock";
    device = lib.mkOption {
      type = lib.types.str;
      default = lib.throwIfNot false "custom.boot.keyfile-unlock is enabled but no device is set. Please set custom.boot.keyfile-unlock.device";
      description = "The device to use for keyfile unlock";
    };
    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = lib.throwIfNot false "custom.boot.keyfile-unlock is enabled but no keyFile is set. Please set custom.boot.keyfile-unlock.keyFile";
      description = "The keyfile to use for keyfile unlock";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd = {
      luks.devices."${cfg.device}" = {
        keyFile = cfg.keyFile;
        keyFileTimeout = 5;
      };
    };
  };
}
