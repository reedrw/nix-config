{ pkgs, lib, ... }:

{
  pre-commit.settings = {
    hooks = {
      trim-trailing-whitespace.enable = true;
      shellcheck.enable = true;
      statix.enable = true;
      deadnix.enable = true;
      no-empty-module-arg = {
        enable = true;
        name = "no-empty-module-arg";
        description = "ban a bare `_:` at the top of nix files";
        entry = lib.getExe <| pkgs.writeNixShellScript "no-empty-module-arg" (
          builtins.readFile ./no-empty-module-arg.sh
        );
        files = "\\.nix$";
        language = "system";
      };
    };
  };
}
