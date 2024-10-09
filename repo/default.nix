{ inputs, nixConfig, ... }:
let
  versionSuffix = "${builtins.substring 0 8 (inputs.self.lastModifiedDate or inputs.self.lastModified)
                  }_${inputs.self.shortRev or "dirty"}";
  nixpkgs-options.nixpkgs = {
    overlays = [
      (import ../pkgs)
      (import ../pkgs/branches.nix inputs)
      (import ../pkgs/pin/overlay.nix)
      (import ../pkgs/alias.nix inputs)
      # (import ../pkgs/lib.nix)
      (import ../pkgs/functions.nix)
    ];
    config = import ../pkgs/config.nix {
      inherit inputs;
    };
  };

  pkgsForSystem = src: system:
    import src (nixpkgs-options.nixpkgs // {
        inherit system;
    });

in
{
  ezConfigs = {
    globalArgs = {
      inherit inputs nixpkgs-options nixConfig versionSuffix;
    };

    home.users."reed".nameFunction = (_: "reed");
    home.users."reed@nixos-desktop".nameFunction = (_: "reed@nixos-desktop");
  };

  perSystem = { pkgs, inputs', ... }: rec {
    legacyPackages = (pkgsForSystem inputs.nixpkgs pkgs.system) // {
      pkgs-unstable = pkgsForSystem inputs.unstable pkgs.system;
    };

    devShells.default = import ../shell.nix {
      pkgs = legacyPackages;
    };
  };
}
