{
  lib,
  inputs,
  appendOverlays,
  makeRustPlatform,
  fetchFromGitHub,
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

  meta = {
    description = "LD_PRELOAD compatibility runtime for Windows games under Wine/Proton";
    homepage = "https://github.com/brcly/linuwux-runtime";
    license = lib.licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "linuwux";
  };
})
