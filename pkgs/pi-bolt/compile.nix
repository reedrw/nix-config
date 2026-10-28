# Pi-Bolt with the local extension set compiled in.
#
# Pi loads extensions from ~/.pi/agent by transpiling them with jiti at every
# start; with this repo's plugin set that is ~180ms of a ~330ms cold start.
# `pi-bolt compile` builds the same release with those extensions already
# bundled and AOT-compiled to machine code, so starting one costs a fingerprint
# check instead of a transpile. That has to happen at build time: compile
# rewrites its own installation, which is read-only once in the store.
#
# The resulting binary still discovers extensions normally and falls back to
# transpiling any whose fingerprint does not match what was baked in (a
# hand-edited ~/.pi/agent file, say), so a mismatch costs startup time, never
# correctness. `compile` keys each extension by the realpath of its entry file,
# which is why the agent dir below is assembled from symlinks to the same store
# paths home-manager deploys rather than from copies.
#
# Two sandbox quirks shape this file:
#
#   * `compile` reports "the build stopped" when its stdout is not a terminal,
#     so it runs under `script`.
#   * even under a pty it exits 1 in a Nix build: its last step re-runs the
#     executable it just built to check it, gets no output ("the new executable
#     does not run as it should: undefinedundefined") and deletes it. The build
#     it rejected is fine, so when that happens we run its bundler ourselves
#     from the staging it leaves behind (the AOT command and its environment are
#     the ones the release's own compiler uses; `compile` prints them in its
#     help). Either way, the result is then measured rather than trusted:
#     extensions that really were compiled in cost ~0ms to load, one that fell
#     back costs 5-110ms.
{
  lib,
  stdenv,
  stdenvNoCC,
  writeText,
  patchelf,
  util-linux,
  pi-bolt,
  runtime,
  kit,

  # Destination below the agent dir -> store path, e.g.
  #   { "extensions/custom-ui.ts" = "/nix/store/…-pi-extension-custom-ui/custom-ui.ts";
  #     "pi-subagents" = "/nix/store/…-pi-npm-root-pi-subagents"; }
  agentFiles,

  # The subset of settings.json `compile` reads: the local packages to compile
  # in, as absolute store paths (see the note where this is passed).
  settings,
}:
let
  relPath = lib.removePrefix ".pi/agent/";

  # Loading this many extensions from files instead of compiled in would show up
  # in the verification below as tens of milliseconds; the compiled ones add
  # ~10ms together.
  maxExtensionLoadMs = 20;

  # The names `compile` compiles in: one per extension file directly under
  # extensions/, and one per package directory. Shared library code
  # (extensions/lib/…) and generated assets are not extensions and are passed
  # over, so they are not expected here.
  extensionNames = lib.sort (a: b: a < b) (
    lib.concatMap (
      dest:
      let
        parts = lib.splitString "/" (relPath dest);
      in
      if lib.length parts == 1 then
        [ (lib.head parts) ]
      else if lib.length parts == 2 && lib.head parts == "extensions" then
        [ (lib.removeSuffix ".ts" (lib.last parts)) ]
      else
        [ ]
    ) (lib.attrNames agentFiles)
  );

  agentFileList = writeText "pi-agent-files" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (dest: source: "${relPath dest}\t${source}") agentFiles
    )
    + "\n"
  );

  # `PIBOLT_BUILD` is baked into the executable and printed by --version.
  jitState = if lib.hasInfix "-jit" pi-bolt.variant then "jit-on" else "jit-off";
  buildId = builtins.substring 0 16 (
    builtins.hashString "sha256" (lib.concatStringsSep "," extensionNames)
  );
  piboltBuild = "${pi-bolt.version} ${pi-bolt.variant} ${jitState} ${buildId}";

  bunTarget =
    {
      x86_64-linux = "bun-linux-x64";
      aarch64-linux = "bun-linux-arm64";
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "pi-bolt: no bun target for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "pi-bolt-compiled";
  inherit (pi-bolt) version;

  # `script` for the pty below, patchelf for the bundled executable (Bun writes
  # it with a generic /lib64 dynamic loader, which does not exist on NixOS).
  nativeBuildInputs = [ util-linux patchelf ];

  # Nothing to unpack: the release is copied out of ${pi-bolt} in buildPhase.
  unpackPhase = "true";

  buildPhase = ''
    runHook preBuild

    # `compile` rewrites both the installation it runs from and the kit it
    # bundles against, and both inputs are read-only store paths.
    cp -a ${pi-bolt}/lib/pi-bolt inst
    chmod -R u+w inst
    cp -a ${kit} kit
    chmod -R u+w kit

    # The extension set to bake in. Symlinks, not copies: see the header.
    mkdir -p home/.pi/agent
    while IFS=$'\t' read -r dest source; do
      mkdir -p "$(dirname "home/.pi/agent/$dest")"
      ln -s "$source" "home/.pi/agent/$dest"
    done < ${agentFileList}

    # Only the package list matters here; the rest of the real settings.json
    # (theme, model, tools) has no bearing on what gets compiled.
    install -m644 ${writeText "pi-compile-settings.json" (builtins.toJSON settings)} \
      home/.pi/agent/settings.json

    export HOME=$PWD/home
    # Not compile.log: `compile` writes its own file by that name here, and two
    # writers would interleave into NUL-padded garbage.
    if script -qefc \
      './inst/pi compile --runtime ${runtime}/bin/bun --kit "$PWD/kit" --out "$PWD/compiled"' \
      /dev/null > compile-output.log 2>&1; then
      echo "compile exited 0"
    else
      echo "compile exited $? (keeping the build it left behind)"
    fi
    cat compile-output.log

    if [ -x compiled/pi ]; then
      cp compiled/pi compiled-pi
    else
      # `compile` bailed out after its bundler ran: the staging it produced
      # (.pibolt-plugins: entry.ts, sources.json, the copied extensions) is the
      # part that matters, so bundle it the way its compiler does.
      stage=kit/tree/packages/coding-agent/.pibolt-plugins
      if [ ! -f "$stage/entry.ts" ] || [ ! -f "$stage/sources.json" ]; then
        echo "error: compile left no usable staging behind" >&2
        [ -f compile.log ] && cat compile.log >&2
        exit 1
      fi
      (
        cd kit/tree/packages/coding-agent
        env \
          BUN_JSC_useJIT=0 \
          BUN_STATIC_HEAP=1 \
          BUN_AOT=1 \
          BUN_JSC_omitBytecodeFromStaticHeap=1 \
          BUN_JSC_useAOTLoopSplitting=1 \
          BUN_JSC_aotLoopSplittingPolicy=5 \
          BUN_JSC_useImmutableIntrinsics=1 \
          BUN_JSC_aotRegExpsPath="$PWD/../../../profile/regexps.txt" \
          BUN_STATIC_HEAP_FUNCTIONS_FIRST="$PWD/../../../profile/heap-functions.txt" \
          BUN_AOT_JIT=0 \
          BUN_AOT_CPU=baseline \
          ${runtime}/bin/bun build --compile \
            --no-compile-autoload-bunfig \
            --no-compile-autoload-dotenv \
            --compile-autoload-package-json \
            --target=${bunTarget} \
            --bytecode \
            --format=esm \
            --splitting \
            --bytecode-order="$PWD/../../../profile/bytecode.order" \
            --compile-exec-argv=--smol \
            --define "PIBOLT_BUILD=\"${piboltBuild}\"" \
            ./.pibolt-plugins/entry.ts \
            ./src/utils/image-resize-worker.ts \
            ./src/extensions/codemode/worker.ts \
            --outfile "$HOME/../compiled-pi"
      )
    fi
    chmod 755 compiled-pi
    patchelf \
      --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath [ stdenv.cc.libc ]}" \
      compiled-pi

    # The binary must report the release it was built from, and must not have
    # lost the compile-time extension set.
    ./compiled-pi --version > version.txt
    cat version.txt
    grep -qF "${pi-bolt.version}" version.txt || {
      echo "error: the compiled executable does not report ${pi-bolt.version}" >&2
      cat version.txt >&2
      exit 1
    }

    # Measured, not asked: `PI_TTI_TRACE` reports how long resource loading
    # (extension discovery + factories) took. Compiled-in extensions cost a
    # fingerprint check each; anything that fell back to TypeScript costs its
    # transpile again. Interactive mode is what emits the trace, and it never
    # exits on its own, hence the timeout.
    set +e
    timeout 60 script -qefc \
      'PI_TTI_TRACE=1 ./compiled-pi --offline --no-mcp' /dev/null > tti.log 2>&1
    set -e
    loadedMs=$(sed -nE 's/.*pi-tti [0-9.]+ \+([0-9.]+) resources\.loaded.*/\1/p' tti.log | head -n 1)
    if [ -z "$loadedMs" ]; then
      echo "error: could not measure extension load time" >&2
      tail -n 20 tti.log >&2
      exit 1
    fi
    echo "extension load: ''${loadedMs}ms (limit ${toString maxExtensionLoadMs}ms)"
    if [ "''${loadedMs%%.*}" -ge ${toString maxExtensionLoadMs} ]; then
      echo "error: extensions loaded from files instead of compiled in" >&2
      grep -E "pi-tti .*resources.loaded" tti.log >&2
      echo "expected these compiled in: ${lib.concatStringsSep ", " extensionNames}" >&2
      exit 1
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/pi-bolt
    # The release's data files (themes, docs, export templates, native module)
    # plus the compiled executable in place of the stock one. The binary looks
    # for them next to itself.
    cp -a ${pi-bolt}/lib/pi-bolt/. $out/lib/pi-bolt/
    chmod u+w $out/lib/pi-bolt/pi
    cp compiled-pi $out/lib/pi-bolt/pi
    chmod 755 $out/lib/pi-bolt/pi
    ln -s ../lib/pi-bolt/pi $out/bin/pi-bolt
    runHook postInstall
  '';

  # The executable is a Bun binary with its bundle appended past the ELF
  # sections; strip() would drop it.
  dontStrip = true;
  dontPatchELF = true;

  meta = pi-bolt.meta // {
    description = "Pi coding agent compiled ahead of time, with the local extension set baked in";
    mainProgram = "pi-bolt";
  };
}
