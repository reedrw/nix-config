self: pkgs:
let
  lib = pkgs.lib;
in
{
  bashmount = if self.hasMainProgram pkgs.bashmount
    then lib.warn "bashmount in nixpkgs has a mainProgram attribute. Remove this override."
         pkgs.bashmount
    else pkgs.pinned.bashmount.v4_3_2;

  clipit = if self.hasMainProgram pkgs.clipit
    then lib.warn "clipit in nixpkgs has a mainProgram attribute. Remove this override."
         pkgs.clipit
    else pkgs.pinned.clipit.v1_4_5;

  fzf-tab = pkgs.zsh-fzf-tab;
}
