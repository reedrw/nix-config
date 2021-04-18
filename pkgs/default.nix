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
  ranger = super.ranger.overrideAttrs (
    old: rec {
      postFixup = old.postFixup + ''
        sed -i "s_#!/nix/store/.*_#!${super.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
      '';
    }
  );
}
