{ osConfig, lib, nixpkgs-options, versionSuffix, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  nix = {
    package = lib.mkDefault osConfig.nix.package;
    settings.use-xdg-base-directories = true;
  };

  xdg.dataFile."home-manager/tree-version".text = versionSuffix;
}
