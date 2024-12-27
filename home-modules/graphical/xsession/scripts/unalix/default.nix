{ python3Packages, getInputs, ... }:

let
 sources = getInputs { root = ./sources; };
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  patches = [ ./update.patch ];

  doCheck = false;
}
