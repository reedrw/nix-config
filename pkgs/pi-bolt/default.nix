{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
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
    x64 = "sha256-69yqb2oNBPZkRnDFmeVYRBoiOEgLNJM0WEAj2I+Wy00=";
    x64-baseline = "sha256-UFeEZF8xQmnHq6tPPlGMRO2C8/iDTMVV/+dGFsBXrZk=";
    x64-jit = "sha256-G3TmNnox4kzqLuKv3dQXO+xBJ8g3MDadJL6aSRRAB4E=";
    arm64 = "sha256-z0cpHsBx1nBlJhhg5A4afZhk3YIuXJn2dpLv7snU3yo=";
    arm64-jit = "sha256-lkemoyb6TyAqH2PZrdjxArhjHmb1Vu0PN6DAhOjWW/c=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "pi-bolt";
  version = "1.0.1";

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
