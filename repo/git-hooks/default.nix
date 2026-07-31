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
      no-rec = {
        enable = true;
        name = "no-rec";
        description = "ban the `rec` keyword in nix files";
        entry = lib.getExe <| pkgs.writeNixShellScript "no-rec" (
          builtins.readFile ./no-rec.sh
        );
        files = "\\.nix$";
        language = "system";
      };
      check-coauthor = {
        enable = true;
        name = "check-coauthor";
        description = "require a Co-Authored-By trailer on AI-agent commits";
        entry = lib.getExe <| pkgs.writeNixShellScript "check-coauthor" (
          builtins.readFile ./check-coauthor.sh
        );
        stages = [ "commit-msg" ];
        language = "system";
      };
    };
  };
}
