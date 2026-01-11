{ pkgs, lib, ...}:

{
  home.packages = with pkgs; [
    git
    gh
  ];
  programs.zsh.initContent = lib.mkAfter ''
    function git(){
      case "$1" in
        ~)
          cd "$(command git rev-parse --show-toplevel)"
        ;;
        clone)
          ${pkgs.hub}/bin/hub clone --recurse-submodules "''${@:2}"
        ;;
        *)
          ${pkgs.hub}/bin/hub "$@"
        ;;
      esac
    }
  '';

  custom.persistence = {
    directories = [
      ".config/gh"
      ".config/git"
    ];
    files = [
      ".config/hub"
    ];
  };
}
