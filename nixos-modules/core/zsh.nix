{
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    promptInit = "";
    shellInit = ''
      export ZDOTDIR=$HOME/.local/share/zsh
    '';
  };
  environment.pathsToLink = [ "/share/zsh" ];
}
