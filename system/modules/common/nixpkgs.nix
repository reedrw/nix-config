{ nixpkgs-options, nixConfig, inputs, config, lib, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  nix = {
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      inherit (nixConfig) extra-substituters extra-trusted-public-keys;
    };
    extraOptions = ''
      builders-use-substitutes = true
      keep-derivations = true
      keep-outputs = true
      use-xdg-base-directories = true
      experimental-features = flakes nix-command repl-flake
    '';
    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
      "unstable=${inputs.unstable.outPath}"
    ];
    registry = {
      unstable.flake = inputs.unstable;
      nixpkgs.flake = inputs.nixpkgs;
    };
  };

  # exclude nix-daemon from mullvad-vpn
  systemd.services.nix-daemon = let
    cfg = config.services.mullvad-vpn;
  in lib.mkIf cfg.enable {
    after = [ "mullvad-daemon.service" ];
    serviceConfig.ExecStart = [
      ""
      "${cfg.package}/bin/mullvad-exclude ${config.nix.package}/bin/nix-daemon --daemon"
    ];
  };
}
