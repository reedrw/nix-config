self: pkgs:
let
  lib = pkgs.lib;
in
{
  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  # https://github.com/NixOS/nixpkgs/pull/317924
  mods = if pkgs.mods.version != "1.3.1"
  then lib.warn "mods version changed. PR should be merged." pkgs.pinned.mods.v1_4_0
  else pkgs.pinned.mods.v1_4_0;
}
