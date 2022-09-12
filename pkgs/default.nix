self: super: {
  ranger = super.ranger.overrideAttrs (
    old: rec {
      postFixup = old.postFixup + ''
        sed -i "s_#!/nix/store/.*_#!${super.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
      '';
    }
  );
  discord = super.discord.override {
    nss = super.nss_latest;
  };
  discord-canary = super.discord-canary.override {
    nss = super.nss_latest;
  };
  nix-prefetch = (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/6ef551fa62943a7b8b1f8ac6d36536b6f4590000.tar.gz) {}).nix-prefetch;
}
