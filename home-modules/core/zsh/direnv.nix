{ pkgs, util, ... }:
let
  sources = (util.importFlake ./plugins).inputs or {};
in
{
  imports = [
    sources.direnv-instant.homeModules.direnv-instant
  ];

  programs.direnv = {
    enable = true;
    nix-direnv = {
      enable = true;
    };
    config = {
      hide_env_diff = true;
      load_dotenv = true;
    };
  };

  programs.direnv-instant = {
    enable = true;
    package = sources.direnv-instant.packages."${pkgs.stdenv.hostPlatform.system}".default;
  };

  custom.persistence.directories = [
    ".local/share/direnv"
  ];
}
