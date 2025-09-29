{ fetchFromGitHub, buildDotnetModule, dotnetCorePackages, ... }:

buildDotnetModule (self: {
  pname = "wheel-wizard";
  version = "2.3.3";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = self.version;
    sha256 = "sha256-DuEI6bmvNP6wRuZX9Do0FGDsu80ldy0SCefBk6gqT9s=";
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
})
