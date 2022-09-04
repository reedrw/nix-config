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
  # https://github.com/NixOS/nixpkgs/pull/189549
  discord-canary = (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/1a03c4a771e8d09b25996f56b9ceafb2aaa8ee4a.tar.gz) {}).discord-canary.override {
    nss = super.nss_latest;
  };
}
