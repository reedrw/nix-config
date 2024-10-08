inputs:
_: pkgs:
{
  nur = import inputs.NUR {
    inherit pkgs;
    nurpkgs = pkgs;
  };
  pinned = import ./pin/pkgs.nix pkgs;
  # pkgs-unstable = import inputs.unstable { inherit (pkgs) config system; };
}
