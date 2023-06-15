# A nixpkgs instance that is grabbed from the pinned nixpkgs commit in the lock file
# This is useful to avoid using channels when using legacy nix commands
input:
let lock = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.${input}.locked;
in with lock; fetchTarball {
  url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
  sha256 = narHash;
}
