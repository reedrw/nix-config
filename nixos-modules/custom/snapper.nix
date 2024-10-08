{ lib, config, ... }:
let
  cfg = config.custom.snapper;
in
{
  options.custom.snapper= {
    enable = lib.mkEnableOption "enable Snapper";

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to create snapshots";
    };
  };

  config = lib.mkIf cfg.enable {
    services.snapper = {
      configs.persist = {
        SUBVOLUME = "${config.custom.persistDir}";
        ALLOW_USERS = cfg.allowedUsers;
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "168";
        TIMELINE_LIMIT_DAILY = "365";
        TIMELINE_LIMIT_WEEKLY = "100";
        TIMELINE_LIMIT_MONTHLY = "36";
        TIMELINE_LIMIT_YEARLY = "0";
      };
    };
  };
}
