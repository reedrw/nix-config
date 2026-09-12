{
  buildFHSEnv,
  callPackage,
  runCommand,
  patchelf,
  libxml2,
  writeShellScript,
  zlib,
  stdenv,
  glibc,
  coreutils,
  bash,
  libGL,
  openssl,
  icu,
  python3,
  git,
  cargo,
  rustc,
  pkg-config,
  vulkan-headers,
  vulkan-loader,
  alsa-lib,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxscrnsaver
}:

let
  wheel-wizard-unwrapped = callPackage ./unwrapped.nix { };

  # libxml2 ≥ 2.15 dropped the libxml2.so.2 soname that WiiCompiled's bundled
  # ld.lld is linked against. Shim the old soname onto the new lib; it must be
  # a regular targetPkgs entry so it exists before ldconfig builds the cache.
  libxml2-so2-shim = runCommand "libxml2-so2-shim"
    {
      nativeBuildInputs = [ patchelf ];
      disallowedReferences = [ libxml2 ];
    }
    ''
    mkdir -p $out/lib
    cp ${libxml2.out}/lib/libxml2.so.16.1.3 $out/lib/libxml2.so.2
    chmod +w $out/lib/libxml2.so.2
    patchelf --set-soname libxml2.so.2 $out/lib/libxml2.so.2
  '';

  wheel-wizard-fhs = buildFHSEnv {
    inherit (wheel-wizard-unwrapped) version;
    pname = "WheelWizard";

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
    targetPkgs = _: [
      wheel-wizard-unwrapped
      zlib
      stdenv.cc.cc.lib
      stdenv.cc.cc.out
      glibc.dev
      coreutils
      bash
      libGL
      openssl
      libxml2
      libxml2-so2-shim
      icu
      python3
      git
      cargo
      rustc
      pkg-config
      vulkan-headers
      vulkan-loader
      alsa-lib
      wayland
      wayland-protocols
      wayland-scanner
      libx11.dev
      libxcursor.dev
      libxi.dev
      libxrandr.dev
      libxscrnsaver
    ];

    # Export the FHS /usr/bin onto PATH: the app inherits the desktop session's
    # PATH, but Corrosion (vendored nod) needs rustc/cargo and SDL/Dawn need
    # python3/wayland-scanner from this environment, not the host.
    runScript = writeShellScript "wheel-wizard-run" ''
      export PATH="/usr/bin:/usr/sbin:$PATH"
      exec WheelWizard "$@"
    '';

    meta = {
      mainProgram = "WheelWizard";
    };
  };
in wheel-wizard-fhs
