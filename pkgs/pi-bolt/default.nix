{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  patchelf,
  versionCheckHook,
  libxcb,

  # Upstream's CPU flavours, as named by PIBOLT_VARIANT and in the release
  # assets. The x64 build needs AVX2 (Intel Haswell / AMD Zen and later), the
  # x64-baseline build runs on any x86-64 CPU and is therefore the default; the
  # -jit builds only matter for extensions that do heavy work or call into
  # native libraries through bun:ffi.
  variant ?
    {
      x86_64-linux = "x64-baseline";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "pi-bolt: no upstream build for ${stdenv.hostPlatform.system}"),
}:

let
  hashes = {
    x64 = "sha256-B81u/om5Zdvz3DWCQEWOcDY92gytFAWQwQmo9gBtiDg=";
    x64-baseline = "sha256-ntQuvb9Q0BQ6zEJkr5ijwATzzxMq/y0ky66swI++sfc=";
    x64-jit = "sha256-uwp8aDb52XvXI4Aj+Uzx2Bfl5cTqTRMiFsk9HKPl+to=";
    arm64 = "sha256-YHCWX0ILpxXF1g0TU9HR1C874zcprgI9CQRjHC83foU=";
    arm64-jit = "sha256-+VzdaH2EWf9oB0yqGuPuFr4nrhFSOVyJAeUOsh2NBUM=";
  };

  # `pi-bolt compile` (compile.nix) needs two extra release assets, per
  # platform rather than per variant: a stock Bun runtime to bundle the
  # extensions with, and the "compile kit" (node_modules and build scaffolding)
  # they are bundled against. Fetched here so compiling needs no network.
  compileHashes = {
    x64-runtime = "sha256-yvnXTW9iA+iT4NyrYSeVnJdAsq++WCr/1zqCUItZyrg=";
    x64-kit = "sha256-rxdktiFcBcOsL7yR/+3aThKz83JY2yd1kxRMLGtdBOs=";
    arm64-runtime = "sha256-5yEfdDN4wzlbrBKLqgZE5Us82SOoW15+ml72rDIJraA=";
    arm64-kit = "sha256-zwN9FJGEP9nMT0lBzr9GH62fEbzco3VGxl134/6ihsw=";
  };
in
stdenv.mkDerivation (finalAttrs:
  let
    runtimeFlavour =
      {
        x86_64-linux = "x64";
        aarch64-linux = "arm64";
      }
      .${stdenv.hostPlatform.system}
        or (throw "pi-bolt: no compile assets for ${stdenv.hostPlatform.system}");

    # Bun as shipped for compiling against; only the dynamic loader needs
    # fixing up for NixOS.
    compileRuntime = stdenvNoCC.mkDerivation {
      pname = "pi-bolt-runtime";
      inherit (finalAttrs) version;

      src = fetchurl {
        url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${finalAttrs.version}/pi-bolt-runtime-linux-${runtimeFlavour}.tar.gz";
        hash = compileHashes."${runtimeFlavour}-runtime";
      };

      nativeBuildInputs = [ patchelf ];
      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 bun $out/bin/bun
        patchelf \
          --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
          --set-rpath "${lib.makeLibraryPath [ stdenv.cc.libc ]}" \
          $out/bin/bun
        runHook postInstall
      '';

      meta.platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };

    # The kit is a tree `compile` bundles against and then rewrites; left
    # read-only like any store path, compile.nix works on a writable copy.
    compileKit = stdenvNoCC.mkDerivation {
      pname = "pi-bolt-kit";
      inherit (finalAttrs) version;

      src = fetchurl {
        url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${finalAttrs.version}/pi-bolt-kit-linux-${runtimeFlavour}.tar.gz";
        hash = compileHashes."${runtimeFlavour}-kit";
      };

      sourceRoot = "pi-bolt-kit-linux-${runtimeFlavour}";
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -a ./. $out/
        runHook postInstall
      '';
    };
  in
  {
  pname = "pi-bolt";
  version = "1.0.9";

  src = fetchurl {
    url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${finalAttrs.version}/pi-bolt-linux-${variant}.tar.xz";
    hash =
      hashes.${variant}
        or (throw
          "pi-bolt: unknown variant '${variant}', expected one of: ${lib.concatStringsSep ", " (lib.attrNames hashes)}");
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  # linux-platform-x11.node links against libxcb; the pi binary itself needs
  # only glibc, whose loader and libraries autoPatchelfHook picks up.
  buildInputs = [ libxcb ];

  # The executable is a Bun binary with the bundle appended past its sections;
  # strip() rewrites the file and drops it.
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  # The executable loads themes, export templates, docs and the X11 module from
  # the directory it lives in, so the whole archive is installed as one tree and
  # only linked into $out/bin. /proc/self/exe resolves the symlink, so the
  # binary still finds those files where they are.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/pi-bolt
    cp -a . $out/lib/pi-bolt
    ln -s ../lib/pi-bolt/pi $out/bin/pi-bolt

    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = ./update.sh;
    inherit compileRuntime compileKit variant;
    # The Pi release this Pi-Bolt build is compiled from, not the Pi-Bolt
    # release version: `pi-bolt --version` prints both. Used by pi settings
    # that track Pi's changelog.
    piVersion = "1.4.0";
  };

  meta = {
    description = "Pi coding agent compiled ahead of time to a native executable";
    longDescription = ''
      Pi-Bolt is the Pi coding agent compiled to machine code: a single
      executable, with no Node.js or Bun needed at run time, that reads the same
      ~/.pi/agent configuration as Pi.

      This packages upstream's prebuilt release; override `variant` to pick
      another CPU flavour (x64, x64-jit, arm64, arm64-jit). `pi-bolt update` and
      `pi-bolt update --rollback` cannot write to the Nix store, so update the
      package instead.
    '';
    homepage = "https://github.com/opensec-git/Pi-Bolt";
    downloadPage = "https://github.com/opensec-git/Pi-Bolt/releases";
    changelog = "https://github.com/opensec-git/Pi-Bolt/blob/pi-bolt/CHANGELOG.md";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "pi-bolt";
  };
})
