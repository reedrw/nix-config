{ python3Packages, importFlake, ... }:

let
 sources = (importFlake ./sources).inputs;
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  patches = [ ./update.patch ];

  doCheck = false;
}
