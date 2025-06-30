{ fetchFromGitHub, buildDotnetModule, dotnetCorePackages, ... }:

buildDotnetModule rec {
  pname = "wheel-wizard";
  version = "2.3.1";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = version;
    sha256 = "sha256-dp/AZ4JaIrqpKovrvJc7zSlbxPwBMSuQyn5mbqkaZik=";
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

  meta = {
    mainProgram = "WheelWizard";
  };
}
