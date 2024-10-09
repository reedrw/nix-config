{ nixpkgs-options, nixConfig, inputs, lib, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  # this is fucking COOKED. When I try to pass a nixpkgs-unstable instance through specialArgs, it fails
  # when I try to pass it through an overlay, it fails, but adding it as a flake output and then passing THAT
  # through _module.args somehow works????
  # TODO: investigate more later
  _module.args.pkgs-unstable = inputs.self.legacyPackages.x86_64-linux.pkgs-unstable;

  environment.etc = lib.mapAttrs' (n: v:
    lib.nameValuePair ("nix/inputs/${n}") ({ source = v.outPath; })
  ) inputs;

  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = [ "flakes" "nix-command" "repl-flake" "pipe-operator" ];
      extra-substituters = nixConfig.extra-substituters ++ [ ];
      extra-trusted-public-keys = nixConfig.extra-trusted-public-keys ++ [ ];
      keep-derivations = true;
      keep-outputs = true;
      trusted-users = [ "root" "@wheel" ];
      use-xdg-base-directories = true;
    };
    nixPath = lib.mapAttrsToList (n: v: "${n}=flake:${n}") inputs;
    registry = lib.mapAttrs (n: v: { flake = v; }) inputs;
  };
}
