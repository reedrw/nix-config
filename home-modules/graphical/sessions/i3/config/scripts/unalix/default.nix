{ python3Packages, util, ... }:

let
 sources = (util.importFlake ./sources).inputs;
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  patches = [ ./update.patch ];

  doCheck = false;
}
