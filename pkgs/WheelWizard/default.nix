{ fetchFromGitHub, buildDotnetModule, dotnetCorePackages, ... }:

buildDotnetModule rec {
  pname = "WheelWizard";
  version = "2.1.3";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = version;
    sha256 = "sha256-UcZmpMtXlsfam7rJVQx8wLKVAvR9ZSyhb3/SyVekCwc=";
  };

  projectFile = "WheelWizard.sln";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  executables = ["WheelWizard"];

  packNupkg = true;
}
