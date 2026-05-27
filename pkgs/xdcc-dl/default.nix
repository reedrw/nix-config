{ lib, python3Packages }:

let
  puffotter = python3Packages.buildPythonPackage (self: {
    pname = "puffotter";
    version = "0.17.2";
    pyproject = true;

    src = python3Packages.fetchPypi {
      inherit (self) pname version;
      sha256 = "5dbf0ddf9809db4a72f19cb8000593c3d404189daa936df24a86c0b7b626d3a7";
    };

    build-system = with python3Packages; [ setuptools ];

    patches = [ ./puffotter-importlib-metadata.patch ];

    propagatedBuildInputs = with python3Packages; [
      sentry-sdk
      requests
      colorama
    ];
  });
in
python3Packages.buildPythonApplication (self: {
  pname = "xdcc-dl";
  version = "5.2.1";

  pyproject = true;

  src = python3Packages.fetchPypi {
    inherit (self) pname version;
    sha256 = "ea1f27f9f0d57232600eea55cdc9ab44e98ef16b7e5d5c7f535ef1520680a1d4";
  };

  build-system = with python3Packages; [ setuptools ];

  patches = [ ./case-insensitive-message.patch ];

  pythonRemoveDeps = [ "bs4" "typing" ];

  propagatedBuildInputs = with python3Packages; [
    beautifulsoup4
    requests
    cfscrape
    colorama
    irc
    puffotter
    sentry-sdk
    names
  ];

  meta = with lib; {
    description = "XDCC file downloader using the IRC protocol";
    homepage = "https://gitlab.namibsun.net/namibsun/python/xdcc-dl";
    license = licenses.gpl3Plus;
    mainProgram = "xdcc-dl";
  };
})
