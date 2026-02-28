{
  inputs = {
    zsh-simple-abbreviations = {
      url = "github:DeveloperC286/zsh-simple-abbreviations";
      flake = false;
    };
    direnv-instant = {
      # https://github.com/Mic92/direnv-instant/pull/68
      url = "github:XYenon/direnv-instant/86fd7cbb4a6d893a87090162fe9e875ae72e6da4";
    };
  };
  outputs = _: { };
}
