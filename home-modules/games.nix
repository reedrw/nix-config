{ config, osConfig, pkgs, ... }:
let
  btaUpdater = builtins.fetchurl {
    url = "https://github.com/Better-than-Adventure/bta-multimc-updater/releases/download/r2.0/BTA.Updater.2.0.zip";
    sha256 = "07mi4ak6jz4jgqqvr0hwrl0lxgfmk6rbc1r93qxf3qgqkq009nqx";
  };

  quakeDir = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/Quake";
  quake = pkgs.wrapPackage pkgs.ironwail (x: ''
    pushd ${quakeDir}
      ${x} "\$@"
    popd
  '');
in
{
  stylix.targets = {
    steam.enable = osConfig.programs.steam.enable;
    prismlauncher.enable = true;
  };

  xdg.dataFile."PrismLauncher/instances-compressed/BTA-Updater-2.0.zip".source = btaUpdater;

  home.packages = with pkgs; [
    prismlauncher
  ] ++ lib.optionals osConfig.programs.steam.enable [
    (aliasToPackage {
      quake = "${lib.getExe quake} $@";
    })
  ];
}
