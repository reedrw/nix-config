{ pkgs, inputs, osConfig, lib, root, rootAbsolute, versionSuffix, ... }:

{

  # Must be applied, not at flake level, so that it inherits per-system
  # nixpkgs overlays and configuration.
  _module.args.pkgs-unstable = import inputs.unstable {
    inherit (pkgs) system config;
  };

  _module.args.rootAbsolute =
    builtins.readFile "${root}/nixos-configurations/${osConfig.networking.hostName}/.flake-path"
      |> lib.removeSuffix "\n";

  nix = {
    package = lib.mkDefault osConfig.nix.package;
    settings.use-xdg-base-directories = true;
  };

  xdg.dataFile."home-manager/tree-version".text = versionSuffix;

  xdg.configFile = {
    "nixpkgs/config.nix".text = ''
      import ${rootAbsolute}/pkgs/config.nix {}
    '';
    # "nixpkgs/overlays.nix".text = ''
    #   import ${pkgs.flakePath}/pkgs/overlays.nix {}
    # '';
  };
}
