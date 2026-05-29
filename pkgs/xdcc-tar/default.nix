{ writeNixShellScript }:

writeNixShellScript "xdcc-tar" (builtins.readFile ./xdcc-tar.sh)
