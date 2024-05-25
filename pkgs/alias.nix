self: pkgs:
let
  lib = pkgs.lib;
in
{
  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };
}
