{
  lib,
  inputs,
  appendOverlays,
  makeRustPlatform,
  fetchFromGitHub,
  patchelf,
  stdenv
}:
let
  sources = (inputs.self.legacyPackages."${stdenv.hostPlatform.system}".util.importFlake ./sources).inputs;
  inherit (appendOverlays [ (import sources.rust-overlay) ]) rust-bin;

  rustPlatform = let
    rustBin = rust-bin.stable.latest.default;
  in makeRustPlatform {
    cargo = rustBin;
    rustc = rustBin;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "linuwux-runtime";
  version = "26.09.28.4";

  src = fetchFromGitHub {
    owner = "brcly";
    repo = "linuwux-runtime";
    tag = "v${finalAttrs.version}";
    hash = "sha256-LSe96TqmNLRQ6pkMXZlahlv9C1R7OwbJLqAVsjWtNU0=";
  };

  cargoHash = "sha256-J3eeXYKn11KEuTvVV4DbtWHtpOYgg5qX0kmeuFJSXIc=";

  nativeBuildInputs = [ patchelf ];

  # The shared object is produced by the xtask linker driver (export map,
  # constructor ordering checks, strip), not by a plain `cargo build`.
  buildPhase = ''
    runHook preBuild
    cargo xtask build --output "$PWD/LinUwUx.so"
    runHook postBuild
  '';

  # Upstream's launcher lives as a heredoc inside install.sh; render it with
  # the store path so the wrapper stays in sync with upstream.
  installPhase = ''
    runHook preInstall
    install -Dm0644 LinUwUx.so "$out/lib/LinUwUx.so"
    mkdir -p "$out/bin"
    {
      echo 'cat <<EOF'
      sed -n '/^cat >"$BIN_PATH" <<EOF$/,/^EOF$/p' install.sh | sed '1d'
    } | LIB_PATH="$out/lib/LinUwUx.so" BIN_PATH="$out/bin/linuwux" bash > "$out/bin/linuwux"
    grep -q 'LD_PRELOAD' "$out/bin/linuwux"
    chmod 0755 "$out/bin/linuwux"
    runHook postInstall
  '';

  doCheck = false;

  # The object's only shared dependencies are libc/libm/libdl/libpthread, so
  # stdenv's fixupPhase bakes a RUNPATH into *our* glibc's lib directory -- and
  # that is wrong for an LD_PRELOAD shim. Preloading into a process running a
  # newer glibc (e.g. Bottles' FHS env on glibc 2.44) then pins libm 2.42 in
  # that process, so every later dlopen() of a library built against a newer
  # glibc fails on versioned symbols: libasound.so.2 imports
  # sqrtf@GLIBC_2.43, which kills winealsa.so/winepulse.so and leaves Wine's
  # mmdevapi with no audio driver. Dropping the RUNPATH lets the loader of the
  # host process supply libc/libm, which is correct in every environment.
  postFixup = ''
    patchelf --remove-rpath "$out/lib/LinUwUx.so"
    patchelf --print-rpath "$out/lib/LinUwUx.so" | grep -q . && {
      echo "error: LinUwUx.so still has a RUNPATH" >&2
      exit 1
    }
    true
  '';

  meta = {
    description = "LD_PRELOAD compatibility runtime for Windows games under Wine/Proton";
    homepage = "https://github.com/brcly/linuwux-runtime";
    license = lib.licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "linuwux";
  };
})
