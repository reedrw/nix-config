let
  sources = import ./nix/sources.nix { };

  nur = import sources.NUR { };

  hm-overlay = self: super: {
    home-manager = super.callPackage "${sources.home-manager}/home-manager" { };
  };

  pkgs = import sources.nixpkgs {
    overlays = [
      nur.repos.reedrw.overlays.mkYamlShell
      hm-overlay
      (import ./pkgs)
    ];
  };
in
pkgs.mkYamlShell ./shell.yml
