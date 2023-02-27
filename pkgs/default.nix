_: pkgs:
let
  lib = pkgs.lib;
in
rec {

  inherit ((import ../config.nix).packageOverrides pkgs) nur fromBranch;

  libreoffice = fromBranch.stable.libreoffice;

  discord = pkgs.discord.override {
    nss = pkgs.nss_latest;
  };
  discord-canary = pkgs.discord-canary.override {
    nss = pkgs.nss_latest;
  };

  nom = pkgs.nix-output-monitor;

  # Takes an attribute set and converts into shell scripts to act as "global aliases"
  # Ex.
  # aliasToPackage {
  #   str = "${gcc}/bin/strings $@";
  #   hms = "home-manager switch;
  # }
  aliasToPackage = alias:
    pkgs.symlinkJoin {
      name = "alias";
      paths = (
        lib.mapAttrsToList
        (name: value: pkgs.writeShellScriptBin name value)
        alias
      );
    };

  # Takes a package as input and returns the path to the binary with the same name.
  # Ex.
  # binPath bat
  #
  # Returns:
  # /nix/store/vkbfya4qhmzykw6fqs409q5ajdrnhzlq-bat-0.22.1/bin/bat
  binPath = package: let
    name = (builtins.parseDrvName package.name).name;
  in
    "${package}/bin/${name}";

  # Override a package until next release. Takes current version, package, and override as arguments.
  # Ex.
  # versionConditionalOverride "1.4.1" distrobox
  #   (distrobox.overrideAttrs (
  #     old: rec {
  #       src = pkgs.fetchFromGitHub {
  #         owner = "89luca89";
  #         repo = "distrobox";
  #         rev = "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9";
  #         sha256 = "nIqkptnP3fOviGcm8WWJkBQ0NcTE9z/BNLH/ox6qIoA=";
  #       };
  #     }
  #   ))
  versionConditionalOverride = version: package: override:
    if builtins.compareVersions package.version version < 1
    then override
    else package;

  # Shortens a git commit hash to the first 7 characters
  # Ex.
  # shortenRev "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9"
  #
  # Returns:
  # "acb36a4"
  shortenRev = rev: builtins.substring 0 7 rev;

  # Given a package an niv sources set, overrides package to build from niv source with same name.
  # Ex.
  # `buildFromNivSource i3 sources`
  # will build i3 from sources.i3
  buildFromNivSource = package: sources:
  let
    name = (builtins.parseDrvName package.name).name;
    src = sources."${name}";
    version = shortenRev src.rev;
  in
    package.overrideAttrs (
      _: {
        inherit version src;
      }
    );

  # Given the current version of a package, the package itsef, and a niv sources set, build from
  # niv sources until the version of the package is newer than the specified version.
  # Ex.
  # buildFromNivSourceUntilVersion "1.4.1" distrobox sources
  buildFromNivSourceUntilVersion = version: package: sources:
    versionConditionalOverride version package
      (buildFromNivSource package sources);

  # Given a nixpkgs source as arugment, import it with the current config.
  importNixpkgs = nixpkgs:
    import nixpkgs { inherit (pkgs) config overlays system; };
}
