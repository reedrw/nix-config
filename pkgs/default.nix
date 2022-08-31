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
  # https://github.com/NixOS/nixpkgs/pull/189044
  discord-canary = (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/5f190380aed4f4394c1d30972a52b6a2cdd63d9e.tar.gz) {}).discord-canary.override {
    nss = super.nss_latest;
  };
}
