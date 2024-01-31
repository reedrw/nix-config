{ python3Packages, ... }:

let
 sources = import ./nix/sources.nix { };
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  patches = [ ./update.patch ];

  doCheck = false;
}
