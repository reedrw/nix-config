self: super: rec {

  inherit ((import ../config.nix).packageOverrides super) nur fromBranch;

  ranger = super.ranger.overrideAttrs (
    old: rec {
      postFixup =
        old.postFixup
        + ''
          sed -i "s_#!/nix/store/.*_#!${super.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
        '';
    }
  );

  libreoffice = fromBranch.stable.libreoffice;

  discord = super.discord.override {
    nss = super.nss_latest;
  };
  discord-canary = super.discord-canary.override {
    nss = super.nss_latest;
  };

  nom = super.nix-output-monitor;

  # Takes an attribute set and converts into shell scripts to act as "global aliases"
  # Ex.
  # aliasToPackage {
  #   str = "${gcc}/bin/strings $@";
  #   hms = "home-manager switch;
  # }
  aliasToPackage = alias:
    super.symlinkJoin {
      name = "alias";
      paths = (
        super.lib.mapAttrsToList
        (name: value: super.writeShellScriptBin name value)
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

  shortenRev = rev: builtins.substring 0 7 rev;

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

  buildFromNivSourceUntilVersion = version: package: sources:
    versionConditionalOverride version package
      (buildFromNivSource package sources);

}
