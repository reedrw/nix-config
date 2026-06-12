{ python3Packages, util, ... }:

let
 sources = (util.importFlake ./sources).inputs;
in
python3Packages.buildPythonPackage {
  name = "Unalix";
  src = sources.Unalix;

  pyproject = true;

  build-system = [
    python3Packages.setuptools
  ];

  patches = [ ./update.patch ];

  doCheck = false;
}
