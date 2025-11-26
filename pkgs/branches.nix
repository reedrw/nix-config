inputs:
self: pkgs:
{
  nur = import inputs.NUR {
    inherit pkgs;
    nurpkgs = pkgs;
  };
  pkgs-unstable = import inputs.unstable {
    inherit (pkgs) config;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
}
