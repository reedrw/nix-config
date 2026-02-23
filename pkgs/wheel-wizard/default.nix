{
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  nuget-to-json,
  writeShellScript,
  nix-update,
  lib,
  ...
}:

buildDotnetModule (self: {
  pname = "wheel-wizard";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = self.version;
    sha256 = "sha256-3qFJ08v9JI7VDSG9Nm0EuWJG8WHVLfpkk8TLYezWV5Y=";
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

  passthru.updateScript = writeShellScript "update.sh" ''
    PATH="${lib.makeBinPath [
      dotnetCorePackages.sdk_8_0
      nix-update
      nuget-to-json
    ]}:$PATH"
    set -x
    set -e

    toplevel="$(git rev-parse --show-toplevel)"
    flake="builtins.getFlake \"$toplevel\""

    if test -n "$toplevel"; then
      pushd "$toplevel" || exit 1
        nix-update -F --src-only ${self.pname}
      popd || exit 1
    fi

    version="$(nix eval --impure --raw --expr "($flake).packages.x86_64-linux.wheel-wizard.version")"

    currentDir="$(pwd)"
    tmpDir="$(mktemp -d)"

    pushd "$tmpDir" || exit 1
      git clone --branch "$version" --depth 1 "https://github.com/TeamWheelWizard/WheelWizard.git" .
      dotnet restore --packages deps
      nuget-to-json deps > "$currentDir/deps.json"
    popd || exit 1

    rm -rf "$tmpDir"
  '';
})
