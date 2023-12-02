{ config, lib, ... }:
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
    boot.initrd = {
      supportedFilesystems = [ "btrfs" ];
      postDeviceCommands = lib.mkBefore cfg.wipeScript;
    };
    programs.persist-path-manager = {
      enable = true;
      config = {
        activateCommand = "ldp";
        persistJson = "/home/reed/.config/nixpkgs/system/${config.networking.hostName}/persist.json";
        persistDir = "/persist";
        snapper = {
          enable = true;
          config = "persist";
        };
      };
    };
  };

}
