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
  # https://github.com/NixOS/nixpkgs/pull/191659
  cinny-desktop = super.cinny-desktop.overrideAttrs (
    old: rec {
      buildInputs = old.buildInputs ++ [
        super.openssl_1_1
      ];
    }
  );
  # https://github.com/NixOS/nixpkgs/pull/193868
  fzf = (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/c779b5e306e46b9c571f798aa7d4ce1285239151.tar.gz) {}).fzf;

  # https://github.com/i3/i3/issues/5184
  i3-gaps = (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/f4edfa5f90abd526d563da66c84c29723deb3e9b.tar.gz) {}).i3-gaps;
}
