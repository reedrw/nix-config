{ lib, config, ... }:
let
  cfg = config.custom.torrents;
in
{
  options.custom.torrents = {
    enable = lib.mkEnableOption "Enable Deluge";

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to access the downloads directory";
    };
  };

  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      openFirewall = true;
      web.enable = true;
    };

    users.users = lib.mergeAttrsList (map (name: {
      ${name}.extraGroups = [ "deluge" ];
    }) cfg.allowedUsers);
  };
}
