{ lib, ... }:

{
  options.custom = {
    persistDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mountpoint for persist subvolume";
    };
    prevDir = lib.mkOption {
      type = lib.types.str;
      default = "/prev";
      description = "Mountpoint for previous subvolume";
    };
  };
}
