let

  sources = import ./nix/sources.nix;

in
self: super: {
  tmuxnew = super.tmux.overrideAttrs (
    old: rec {
      version = sources.tmux.rev;
      src = sources.tmux;
    }
  );
  neofetch = super.neofetch.overrideAttrs (
    old: rec {
      version = sources.neofetch.rev;
      src = sources.neofetch;
    }
  );
  discord = (import
    (super.fetchzip {
      url = "https://github.com/nixos/nixpkgs/archive/7138a338b58713e0dea22ddab6a6785abec7376a.zip";
      sha256 = "1asgl1hxj2bgrxdixp3yigp7xn25m37azwkf3ppb248vcfc5kil3";
    })
    { }).discord.overrideAttrs (
    old: rec {
      installPhase = super.lib.strings.concatStrings [
        old.installPhase
        ''
          substituteInPlace $out/opt/Discord/resources/build_info.json \
            --replace '0.0.13' '${super.discord.version}'
        ''
      ];
    }
  );
}
