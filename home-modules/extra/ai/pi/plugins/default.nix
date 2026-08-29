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
#                 transitive deps assembled into node_modules; symlinked to
#                 ~/.pi/agent/<name> and listed in pi's settings.json packages
{
  lib,
  callPackage,
  runCommand,
}:
let
  pins = builtins.fromJSON (builtins.readFile ./pins.json);

  # One derivation per pinned npm package. The set self-references lazily to
  # resolve node_modules dependencies; npm dep graphs are acyclic.
  npmPkgs = lib.mapAttrs (
    name: pin: callPackage ./npm-package.nix { inherit name pin npmPkgs; }
  ) pins.packages;

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

  # Shared library modules for the extensions (lib/claude-style.ts etc.). Not
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

  # Pinned npm roots, keyed by the attr name pi loads them under.
  npmPlugins = lib.listToAttrs (
    map (name: {
      name = lib.last (lib.splitString "/" name);
      value = asPackage npmPkgs.${name};
    }) pins.roots
  );
in
extensionPlugins // libPlugins // vendoredPlugins // npmPlugins
