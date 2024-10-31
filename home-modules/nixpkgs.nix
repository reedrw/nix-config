{ pkgs, osConfig, lib, versionSuffix, inputs, ... }:

{
  _module.args.pkgs-unstable = inputs.self.legacyPackages.x86_64-linux.pkgs-unstable;

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
