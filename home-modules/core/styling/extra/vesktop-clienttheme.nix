{ config, lib, pkgs, ... }:

{
  options.stylix.targets.vesktop-clienttheme.enable = lib.mkEnableOption "Enable Vesktop theme with ClientTheme plugin";
  config = lib.mkIf config.stylix.targets.vesktop-clienttheme.enable {
    home.activation = let
      writeVesktopTheme = pkgs.writeShellScript "write-vesktop-theme" ''
        configFile="$HOME/.config/vesktop/settings/settings.json"
        newConfig="$(${pkgs.jq}/bin/jq -r '.plugins.ClientTheme.color = "${config.lib.stylix.scheme.base00}"' $configFile)"
        echo "$newConfig" > $configFile
      '';
    in {
      updateVesktopTheme = config.lib.dag.entryAfter ["writeBoundary"] ''
        run ${writeVesktopTheme}
      '';
    };
  };
}
