inputs:
_: pkgs:
{
  nur = import inputs.NUR {
    inherit pkgs;
    nurpkgs = pkgs;
  };

  mv = inputs.multiverse.lib.mkMultiverse {
    config = import ./config.nix;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
}
