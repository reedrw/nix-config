let
  sources = import ../nix/sources.nix { };
in
self: super: rec {
  nur = import "${sources.NUR}" {
    pkgs = super;
  };
  master = import "${sources.nixpkgs-master}" { };
  stable = import "${sources.nixpkgs-stable}" { };
  staging-next = import "${sources.nixpkgs-staging-next}" { };

  ranger = super.ranger.overrideAttrs (
    old: rec {
      postFixup =
        old.postFixup
        + ''
          sed -i "s_#!/nix/store/.*_#!${super.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
        '';
    }
  );

  libreoffice = stable.libreoffice;

  discord = super.discord.override {
    nss = super.nss_latest;
  };
  discord-canary = super.discord-canary.override {
    nss = super.nss_latest;
  };

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

  # Override a package until next release. Takes current version, package, and override as arguments.
  # Ex.
  # versionConditionalOverride "1.4.1" distrobox
  #   distrobox.overrideAttrs (
  #     old: rec {
  #       src = pkgs.fetchFromGitHub {
  #         owner = "89luca89";
  #         repo = "distrobox";
  #         rev = "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9";
  #         sha256 = "nIqkptnP3fOviGcm8WWJkBQ0NcTE9z/BNLH/ox6qIoA=";
  #       };
  #     }
  #   )
  versionConditionalOverride = version: package: override:
    if package.version <= version
    then override
    else package;
}
