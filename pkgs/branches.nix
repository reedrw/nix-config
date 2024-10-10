inputs:
self: pkgs:
{
  nur = import inputs.NUR {
    inherit pkgs;
    nurpkgs = pkgs;
  };
  pinned = import ./pin/pkgs.nix pkgs;
}
