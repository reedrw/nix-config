{ config, lib, pkgs, ... }:
let
  cfg = config.custom.boot.wipe;
  wipeScript = builtins.readFile ./wipeScript.sh;
in
{
  options.custom.boot.wipe = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable root wipe on boot with btrfs snapshots.
      '';
    };
    wipeScript = lib.mkOption {
      type = lib.types.str;
      default = wipeScript;
      description = ''
        Script to wipe boot partition.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.systemd.services.rollback = {
      description = "Rollback BTRFS root subvolume to a pristine state";

      wantedBy = [
        "initrd.target"
      ];
      after = [
        # LUKS/TPM process
        "systemd-cryptsetup@enc.service"
      ];
      before = [
        "sysroot.mount"
      ];

      serviceConfig.Type = "oneshot";

      script = cfg.wipeScript;
    };

    programs.persist-path-manager = {
      enable = true;
      config = {
        inherit (config.custom) persistDir prevDir;
        activateCommand = "ldp";
        persistJson = "${pkgs.flakePath}/system/${config.networking.hostName}/persist.json";
        snapper = {
          enable = builtins.hasAttr "persist" config.services.snapper.configs;
          config = "persist";
        };
      };
    };
  };

}
