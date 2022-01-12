{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.themes.base16;
  inherit (builtins) pathExists;

  schemes   = importJSON ./schemes.json;
  templates = importJSON ./templates.json;

  # Data file for a given base16 scheme and variant. Returns the nix store
  # path of the file.
  mkTheme = scheme: variant:
    "${builtins.fetchGit {
      url = schemes.${scheme}.url;
      rev = schemes.${scheme}.rev;
    }}/${variant}.yaml";

  # Source file for a given base16 template.
  # Returns the nix store path of the file.
  mkTemplate = name: type:
    let
      templateDir = "${builtins.fetchGit {
        url = templates.${name}.url;
        rev = templates.${name}.rev;
      }}/templates";
    in
      if pathExists (templateDir + "/${type}.mustache")
      then templateDir + "/${type}.mustache"
      else templateDir + "/default.mustache";

  # The theme yaml files only supply 16 hex values, but the templates take
  # a transformation of this data such as rgb. The hacky python script pre-
  # processes the theme file in this way for consumption by the mustache
  # engine below.
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  preprocess = src:
    pkgs.stdenv.mkDerivation {
      name = "yaml";
      inherit src;
      builder = pkgs.writeText "builder.sh" ''
        slug_all=$(${pkgs.coreutils}/bin/basename $src)
        slug=''${slug_all%.*}
        ${python}/bin/python ${./base16writer.py} $slug < $src > $out
      '';
      allowSubstitutes = false;  # will never be in cache
    };

  # Mustache engine. Applies any theme to any template, providing they are
  # included in the local json source files.
  mustache = scheme: variant: name: type:
    pkgs.stdenv.mkDerivation {
      name = "${name}-base16-${variant}";
      data = preprocess (mkTheme scheme variant);
      src  = mkTemplate name type;
      phases = [ "buildPhase" ];
      buildPhase ="${pkgs.mustache-go}/bin/mustache $data $src > $out";
      allowSubstitutes = false;  # will never be in cache
    };

  mustacheCustom = schemePath: name: type:
    pkgs.stdenv.mkDerivation {
      name = "${name}-base16-scheme";
      data = preprocess schemePath;
      src  = mkTemplate name type;
      phases = [ "buildPhase" ];
      buildPhase ="${pkgs.mustache-go}/bin/mustache $data $src > $out";
      allowSubstitutes = false;  # will never be in cache
    };

  schemeJSON = scheme: variant:
    importJSON (preprocess (mkTheme scheme variant));

  schemeJSONCustom = schemePath:
    importJSON (preprocess schemePath);

in
{
  options = with types; {
    themes.base16 = {
      enable = mkEnableOption "Base 16 Color Schemes";
      customScheme = {
        enable = mkEnableOption "Use custom scheme instead of remote repository";
        path = mkOption {
          type = nullOr path;
          default = null;
        };
      };
      scheme = mkOption {
        type = str;
        default = "solarized";
      };
      variant = mkOption {
        type = str;
        default = "solarized-dark";
      };
      extraParams = mkOption {
        type = attrsOf anything;
        default = {};
      };
      defaultTemplateType = mkOption {
        type = str;
        default = "default";
        example = "colors";
      };
    };
  };
  config = {
    lib.base16.theme =
      if cfg.customScheme.enable then
        schemeJSONCustom cfg.customScheme.path // cfg.extraParams
      else
        schemeJSON cfg.scheme cfg.variant // cfg.extraParams;

    lib.base16.templateFile = { name, type ? cfg.defaultTemplateType, ... }:
      if cfg.customScheme.enable then
        mustacheCustom cfg.customScheme.path name type
      else
        mustache cfg.scheme cfg.variant name type;
  };
}
