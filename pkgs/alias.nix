self: pkgs:
let
  lib = pkgs.lib;
in
{
  # https://github.com/NixOS/nixpkgs/pull/297859
  i3lock-fancy = if pkgs.hasMainProgram pkgs.i3lock-fancy
                 then lib.warn "i3lock-fancy update is merged now!!" pkgs.i3lock-fancy
                 else pkgs.pinned.i3lock-fancy.vunstable-2023-04-28;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };
}
