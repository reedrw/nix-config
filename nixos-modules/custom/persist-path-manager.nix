{ config, pkgs, lib, ... }:

let
  cfg = config.programs.persist-path-manager;
in
{
  options.programs.persist-path-manager = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Enable persist-path-manager";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.persist-path-manager;
      description = lib.mdDoc "Package to use for persist-path-manager";
    };

    config = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.unspecified);
      default = null;
      description = lib.mdDoc "Configuration for persist-path-manager";
    };
  };

  config = let
    package = if cfg.config == null then cfg.package else cfg.package.overrideAttrs (old: {
      text = ''
        #!${pkgs.runtimeShell}
        PPM_CONFIG=${builtins.toFile "config.json" (builtins.toJSON cfg.config)}
      '' + old.text;
    });
  in lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];
  };
}
