{ writeNixShellScript }:

writeNixShellScript "gc" (builtins.readFile ./gc)
