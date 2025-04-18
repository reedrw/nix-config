{ lib, pkgs, config, osConfig, ... }:
let
  quakeDir = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/Quake";
  quake = pkgs.wrapPackage pkgs.ironwail (x: ''
    pushd ${quakeDir}
      ${x} "\$@"
    popd
  '');
in
{
  home.packages = lib.optionals osConfig.programs.steam.enable [
    (pkgs.aliasToPackage {
      quake = "${lib.getExe quake} $@";
    })
  ];
}
