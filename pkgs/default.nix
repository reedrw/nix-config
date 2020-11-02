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
}
