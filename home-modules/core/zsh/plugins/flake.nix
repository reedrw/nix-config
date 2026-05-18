{
  inputs = {
    zsh-simple-abbreviations = {
      url = "github:DeveloperC286/zsh-simple-abbreviations";
      flake = false;
    };
    direnv-instant.url = "github:Mic92/direnv-instant";
    zsh-progress-pane = {
      url = "path:./zsh-progress-pane";
      flake = false;
    };
  };
  outputs = _: { };
}
