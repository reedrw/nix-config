self: pkgs:
let
  lib = pkgs.lib;
in
{
  clipit = if self.hasMainProgram pkgs.clipit
    then lib.warn "clipit in nixpkgs has a mainProgram attribute. Remove this override."
         pkgs.clipit
    else pkgs.pinned.clipit.v1_4_5;
}
