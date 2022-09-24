let
  sources = import ./nix/sources.nix { };
in
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

  # https://github.com/NixOS/nixpkgs/pull/182618
  libadwaita12 = (import sources.nixpkgs { }).libadwaita;
}
