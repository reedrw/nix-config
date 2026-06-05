{ pkgs, ... }:

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
        description = "ban a bare `_:` at the top of nix files; opt out with `# keep-arg`";
        entry = "${pkgs.writeShellApplication {
          name = "no-empty-module-arg";
          text = builtins.readFile ./no-empty-module-arg.sh;
        }}/bin/no-empty-module-arg";
        files = "\\.nix$";
        language = "system";
      };
    };
  };
}
