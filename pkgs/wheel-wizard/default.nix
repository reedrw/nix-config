{ fetchFromGitHub, buildDotnetModule, dotnetCorePackages, csharpier, ... }:

buildDotnetModule rec {
  pname = "wheel-wizard";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = version;
    sha256 = "sha256-Fw/Tj3HVZL1ttH/6eL8G9ZXs74hx+Ec1BOvT0FOicBU=";
  };

  projectFile = "WheelWizard.sln";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  preConfigure = ''
   dotnet tool uninstall csharpier
  '';

  executables = ["WheelWizard"];

  packNupkg = true;
}
