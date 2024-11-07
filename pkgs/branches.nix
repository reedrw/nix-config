inputs:
self: pkgs:
{
  nur = import inputs.NUR {
    inherit pkgs;
    nurpkgs = pkgs;
  };
  pkgs-unstable = import inputs.unstable {
    inherit (pkgs) system config;
  };
  pinned = import ./pin/pkgs.nix pkgs;
}
