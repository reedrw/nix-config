# pi plugins — nix-native packaging for pi coding agent extensions.
#
# Follows the repo convention of a plugins/ dir under a module (mpv, zsh), but
# pins npm tarballs via pins.json + fetchurl instead of flake inputs.
#
# The set is fully data-driven — install/uninstall by editing the directory or
# pins.json, then rerun ./update.sh (also run automatically by `update-all`):
#   - extension:  any *.ts file in this dir, symlinked to
#                 ~/.pi/agent/extensions/<name>.ts
#   - lib:        any *.ts file in lib/, symlinked to
#                 ~/.pi/agent/extensions/lib/<name>.ts — NOT auto-loaded by
#                 pi (only extensions/*.ts and */index.ts are); it's shared
#                 code that extension files import via ./lib/… relative paths
#   - vendored:   any subdirectory with a package.json (+ default.nix), e.g. a
#                 fork like pi-image-view; symlinked to ~/.pi/agent/<name>
#   - pinned npm: roots of pins.json, tarballs fetched at pinned versions with
#                 all pinned deps assembled into one shared flat node_modules
#                 (npm dep graphs can be cyclic, so it cannot be per-package);
#                 symlinked to ~/.pi/agent/<name> and listed in pi's
#                 settings.json packages
{
  lib,
  callPackage,
  runCommand,
}:
let
  pins = builtins.fromJSON (builtins.readFile ./pins.json);

  # One derivation per pinned npm tarball (plain unpack, no node_modules).
  npmPkgs = lib.mapAttrs (
    name: pin: callPackage ./npm-package.nix { inherit name pin; }
  ) pins.packages;

  # npm dependency graphs may contain cycles (es-abstract <->
  # arraybuffer.prototype.slice etc.), which store paths cannot express, so
  # instead of per-package node_modules we build one flat node_modules in
  # npm's deduped layout and root plugins symlink it in. Packages are copied
  # (not symlinked) so Node's realpath-based module resolution stays inside
  # this store path and finds transitive deps as siblings.
  nodeModules = runCommand "pi-npm-node-modules" { } ''
    mkdir -p "$out/node_modules"
    ${lib.concatMapStringsSep "\n" (p: ''
      mkdir -p "$out/node_modules/${dirOf p.npmName}"
      cp -a "${p}/." "$out/node_modules/${p.npmName}"
    '') (lib.attrValues npmPkgs)}
  '';

  dir = builtins.readDir ./.;

  # Tag a plugin as a local-dir package. Ordered so the tagged passthru wins;
  # also drops makeOverridable's override helpers when re-applied.
  asPackage =
    plugin:
    lib.filterAttrs (n: _: n != "override" && n != "overrideDerivation") plugin
    // {
      passthru = (plugin.passthru or { }) // {
        piKind = "package";
      };
    };

  # Local single-file extensions: <name>.ts -> derivation containing <name>.ts.
  extensionPlugins = lib.mapAttrs' (
    file: _:
    let
      name = lib.removeSuffix ".ts" file;
    in
    {
      inherit name;
      value = runCommand "pi-extension-${name}"
        {
          passthru.piKind = "extension";
        }
        ''
          install -Dm644 ${./${file}} "$out/${file}"
        '';
    }
  ) (lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".ts" file) dir);

  # Shared library modules for the extensions (lib/custom-ui.ts etc.). Not
  # auto-discovered by pi, but the extensions' ./lib/… imports resolve against
  # ~/.pi/agent/extensions/lib/ at runtime, so the files must land there.
  libPlugins = lib.mapAttrs' (
    file: _:
    let
      name = lib.removeSuffix ".ts" file;
    in
    {
      name = "lib/${name}";
      value = runCommand "pi-extension-lib-${name}"
        {
          passthru.piKind = "lib";
        }
        ''
          install -Dm644 ${./lib/${file}} "$out/lib/${file}"
        '';
    }
  ) (lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".ts" file) (builtins.readDir ./lib));
  # Vendored packages: subdirectories with a package.json, built by their
  # default.nix (the version lives in package.json).
  vendoredPlugins = lib.mapAttrs (
    name: _: asPackage (callPackage ./${name} { })
  ) (lib.filterAttrs (name: type: type == "directory" && builtins.pathExists ./${name}/package.json) dir);

  # Pinned npm roots, keyed by the attr name pi loads them under. Each is the
  # unpacked package plus a symlink to the shared flat node_modules.
  npmPlugins = lib.listToAttrs (
    map (name: {
      name = lib.last (lib.splitString "/" name);
      value = asPackage (runCommand "pi-npm-root-${lib.replaceStrings [
        "@" "/"
      ] [ "" "-" ] name}" { passthru.npmName = name; } ''
        cp -a "${npmPkgs.${name}}/." "$out/"
        chmod -R u+w "$out"
        ln -s "${nodeModules}/node_modules" "$out/node_modules"
      '');
    }) pins.roots
  );
in
extensionPlugins // libPlugins // vendoredPlugins // npmPlugins
