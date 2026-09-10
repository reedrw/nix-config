{
  fetchFromGitHub,
  buildDotnetModule,
  buildFHSEnv,
  dotnetCorePackages,
  nuget-to-json,
  writeShellScript,
  nix-update,
  lib,
  pkgs,
  ...
}:

let
  wheel-wizard-unwrapped = buildDotnetModule {
    pname = "wheel-wizard-unwrapped";
    version = "2.5.4-unstable-2026-09-09";

    src = fetchFromGitHub {
      owner = "TeamWheelWizard";
      repo = "WheelWizard";
      rev = "6d4024afcbc9e738a9630a08fae2e8cffbd82595";
      sha256 = "sha256-m/2kd2ezNUeJBfOdhcsNfsc1iWzfoCwpiRk//1b/cZs=";
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

      toplevel="$(git rev-parse --show-toplevel)"
      flake="builtins.getFlake \"$toplevel\""

      if test -n "$toplevel"; then
        pushd "$toplevel" || exit 1
          nix-update -F --src-only wheel-wizard
        popd || exit 1
      fi

      version="$(nix eval --impure --raw --expr "($flake).packages.x86_64-linux.wheel-wizard.version")"

      currentDir="$(pwd)"
      tmpDir="$(mktemp -d)"

      pushd "$tmpDir" || exit 1
        git clone --branch "$version" --depth 1 "https://github.com/TeamWheelWizard/WheelWizard.git" . || \
        git clone --branch "v$version" --depth 1 "https://github.com/TeamWheelWizard/WheelWizard.git" .
        dotnet restore --packages deps
        nuget-to-json deps > "$currentDir/deps.json"
      popd || exit 1

      rm -rf "$tmpDir"
    '';
  };

  # libxml2 ≥ 2.15 dropped the libxml2.so.2 soname that WiiCompiled's bundled
  # ld.lld is linked against. Shim the old soname onto the new lib; it must be
  # a regular targetPkgs entry so it exists before ldconfig builds the cache.
  libxml2-so2-shim = pkgs.runCommand "libxml2-so2-shim"
    {
      nativeBuildInputs = [ pkgs.patchelf ];
      disallowedReferences = [ pkgs.libxml2 ];
    }
    ''
    mkdir -p $out/lib
    cp ${pkgs.libxml2.out}/lib/libxml2.so.16.1.3 $out/lib/libxml2.so.2
    chmod +w $out/lib/libxml2.so.2
    patchelf --set-soname libxml2.so.2 $out/lib/libxml2.so.2
  '';

  wheel-wizard-fhs = buildFHSEnv {
    inherit (wheel-wizard-unwrapped) version;
    pname = "wheel-wizard";

    # WheelWizard downloads and executes the WiiCompiled setup AppImage, a
    # generic dynamically-linked binary whose local-build step vendors Dawn,
    # SDL3, libusb and nod (via Corrosion) from source. The packages below are
    # what that from-source build needs on top of the app's own runtime:
    #   - zlib/libstdc++/gcc-rt: libs the AppImage's clang/lld link against
    #   - libGL/vulkan-loader: runtime GL/Vulkan for the game and the app
    #   - glibc.dev + gcc: C/C++ headers and crt files for the clang build
    #   - python3/git: Dawn's fetch_dawn_dependencies + code generators
    #   - rustc/cargo: Corrosion builds the vendored nod crate
    #   - vulkan/x11/wayland/alsa dev stacks: SDL3 video + audio backends
    #   - coreutils/bash: /usr/bin/env + sh, hardcoded by the app itself
    targetPkgs = pkgs: [
      wheel-wizard-unwrapped
      pkgs.zlib
      pkgs.stdenv.cc.cc.lib
      pkgs.stdenv.cc.cc.out
      pkgs.glibc.dev
      pkgs.coreutils
      pkgs.bash
      pkgs.libGL
      pkgs.openssl
      pkgs.libxml2
      libxml2-so2-shim
      pkgs.icu
      pkgs.python3
      pkgs.git
      pkgs.cargo
      pkgs.rustc
      pkgs.pkg-config
      pkgs.vulkan-headers
      pkgs.vulkan-loader
      pkgs.alsa-lib
      pkgs.wayland
      pkgs.wayland-protocols
      pkgs.wayland-scanner
      pkgs.libx11.dev
      pkgs.libxcursor.dev
      pkgs.libxi.dev
      pkgs.libxrandr.dev
      pkgs.libxscrnsaver
    ];

    # Export the FHS /usr/bin onto PATH: the app inherits the desktop session's
    # PATH, but Corrosion (vendored nod) needs rustc/cargo and SDL/Dawn need
    # python3/wayland-scanner from this environment, not the host.
    runScript = pkgs.writeShellScript "wheel-wizard-run" ''
      export PATH="/usr/bin:/usr/sbin:$PATH"
      exec WheelWizard "$@"
    '';

    meta = {
      mainProgram = "wheel-wizard";
    };
  };
in
  wheel-wizard-fhs.overrideAttrs (old: {
    passthru =
      (old.passthru or { })
      // {
        inherit wheel-wizard-unwrapped;
        updateScript = wheel-wizard-unwrapped.passthru.updateScript;
      };
  })
