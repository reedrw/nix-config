{ config, osConfig, lib, ... }:

{
  config = lib.mkIf osConfig.programs.gnupg.agent.enable {
    home.sessionVariables = {
      GNUPGHOME = "${config.xdg.dataHome}/gnupg";
    };

    custom.persistence.directories = [
      ".local/share/gnupg"
    ];
  };
}
