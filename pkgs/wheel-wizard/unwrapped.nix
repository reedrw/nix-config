{ buildDotnetModule, fetchFromGitHub, dotnetCorePackages, writeShellScript, nix-update, nuget-to-json, lib }:

buildDotnetModule (self: {
  pname = "wheel-wizard-unwrapped";
  version = "2.5.6";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    rev = "v${self.version}";
    sha256 = "sha256-jTCHHnba/BCdOYOw9zedkJWdp8MuRrxJKbBHXCzU9I4=";
  };

  projectFile = "WheelWizard.sln";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.runtime_10_0;

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
      dotnetCorePackages.sdk_10_0
      nix-update
      nuget-to-json
    ]}:$PATH"
    set -x
    set -e

    shopt -s dotglob

    toplevel="$(git rev-parse --show-toplevel)"
    flake="builtins.getFlake \"$toplevel\""

    if test -n "$toplevel"; then
      pushd "$toplevel" || exit 1
        nix-update -F --src-only wheel-wizard-unwrapped
      popd || exit 1
    fi

    src="$(nix eval --impure --raw --expr "($flake).packages.x86_64-linux.wheel-wizard-unwrapped.src.outPath")"

    currentDir="$(pwd)"
    tmpDir="$(mktemp -d)"

    pushd "$tmpDir" || exit 1
      cp -r "$src"/* ./
      chmod -R +w ./*
      dotnet restore --packages deps
      nuget-to-json deps > "$currentDir/deps.json"
    popd || exit 1

    rm -rf "$tmpDir"
  '';
})
