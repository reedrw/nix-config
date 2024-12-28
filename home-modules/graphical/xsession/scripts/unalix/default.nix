{ python3Packages, get-flake, ... }:

let
 sources = (get-flake ./sources).inputs;
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  patches = [ ./update.patch ];

  doCheck = false;
}
