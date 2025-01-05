{ python3Packages
, fetchFromGitHub
}:

python3Packages.buildPythonPackage rec {
  pname = "keybind";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "idlesign";
    repo = "keybind";
    rev = "v${version}";
    sha256 = "sha256-EkknH4qNvrsoXUoYJHZyJxMYkWc2CVCEoDhQTWceYjA=";
  };

  propagatedBuildInputs = [
    python3Packages.xlib
  ];
}
