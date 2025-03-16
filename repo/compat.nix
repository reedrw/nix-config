let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  get-flake = import (fetchTarball {
    url = lock.nodes.get-flake.url or "https://github.com/ursi/get-flake/archive/${lock.nodes.get-flake.locked.rev}.tar.gz";
    sha256 = lock.nodes.get-flake.locked.narHash;
  });
in get-flake ../.
