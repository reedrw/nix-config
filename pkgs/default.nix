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

  aliasToPackage = alias: super.symlinkJoin {
    name = "alias";
      paths = (
        super.lib.mapAttrsToList
        (name: value: super.writeShellScriptBin name value)
        alias
      );
    };
}
