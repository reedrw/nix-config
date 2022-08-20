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
  discord-canary = super.discord-canary.override {
    nss = super.nss_latest;
  };
  # Pin mupdf to 1.19.0
  # https://github.com/NixOS/nixpkgs/issues/187305
  mupdf = (import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/9050439c4c1a485a12c5f7754a94ae35dda2699b.tar.gz";
    sha256 = "0pdrr06rzffh08ys3kkanbirjgnawqzxzi61kxdd83z04ndvz2bl";
  }) {}).mupdf;
}
