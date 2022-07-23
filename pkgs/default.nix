self: super: {
  ranger = super.ranger.overrideAttrs (
    old: rec {
      postFixup = old.postFixup + ''
        sed -i "s_#!/nix/store/.*_#!${super.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
      '';
    }
  );
  discord = (super.discord.overrideAttrs (
    old: rec {
      src = builtins.fetchTarball https://discord.com/api/download/stable?platform=linux&format=tar.gz;
    }
  )).override {
    nss = super.nss_latest;
  };
  # libSM dependecy broke.
  # remove below when https://github.com/nixos/nixpkgs/pull/182506 is merged
  slop = super.slop.overrideAttrs (
    old: rec {
      buildInputs = old.buildInputs ++ [ super.xorg.libSM ];
    }
  );
}
