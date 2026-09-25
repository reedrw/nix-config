{
  config,
  lib,
  pkgs,
  util,
  ...
}:
let
  sources = (util.importFlake ./plugins).inputs or {};

  # Pre-bake the hook script instead of forking direnv-instant (`eval "$(hook zsh)"`)
  # on every shell start. Saves ~3ms per prompt.
  direnvInstantHook = pkgs.runCommand "direnv-instant-zsh-hook" { } ''
    ${config.programs.direnv-instant.package}/bin/direnv-instant hook zsh > $out
  '';
in
{
  imports = [
    sources.direnv-instant.homeModules.direnv-instant
  ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
      config = {
        hide_env_diff = true;
        load_dotenv = true;
      };
      # direnv-instant disables direnv's own zsh hook via mkForce only when its
      # integration is enabled; disable it explicitly so HM doesn't add the slow
      # standard `direnv hook zsh` instead.
      enableZshIntegration = false;
    };
    direnv-instant = {
      enable = true;
      # Use the pre-baked hook script instead of the
      # `eval "$(direnv-instant hook zsh)"` that direnv-instant would append
      # to programs.zsh.initContent.
      enableZshIntegration = false;
    };
    zsh.initContent = lib.mkAfter ''
      source ${direnvInstantHook}
    '';
  };

  custom.persistence.directories = [
    ".local/share/direnv"
  ];
}
