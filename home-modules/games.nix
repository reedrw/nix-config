{ config, osConfig, pkgs, ... }:
let
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

  home.packages = with pkgs; [
    prismlauncher
  ] ++ lib.optionals osConfig.programs.steam.enable [
    (aliasToPackage {
      quake = "${lib.getExe quake} $@";
    })
  ];
}
