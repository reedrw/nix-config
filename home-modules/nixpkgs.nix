{ pkgs, osConfig, lib, versionSuffix, ... }:

{
  nix = {
    package = lib.mkDefault osConfig.nix.package;
    settings.use-xdg-base-directories = true;
  };

  xdg.dataFile."home-manager/tree-version".text = versionSuffix;

  xdg.configFile = {
    "nixpkgs/config.nix".text = ''
      import ${pkgs.flakePath}/pkgs/config.nix {}
    '';
    # "nixpkgs/overlays.nix".text = ''
    #   import ${pkgs.flakePath}/pkgs/overlays.nix {}
    # '';
  };
}
