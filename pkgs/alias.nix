self: pkgs:
let
  lib = pkgs.lib;
in
{
  bashmount = if self.hasMainProgram pkgs.bashmount
    then lib.warn "bashmount in nixpkgs has a mainProgram attribute. Remove this override."
         pkgs.bashmount
    else pkgs.pinned.bashmount.v4_3_2;

  fzf-tab = pkgs.zsh-fzf-tab;
}
