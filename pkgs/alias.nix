self: pkgs:
let
  lib = pkgs.lib;
in
{
  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  # https://github.com/NixOS/nixpkgs/pull/322548
  qbittorrent-nox = if builtins.hasAttr "mainProgram" pkgs.qbittorrent-nox.meta
    then lib.warn "qbittorrent-nox mainProgram fixed. PR should be merged." pkgs.pinned.qbittorrent-nox.v4_6_5
    else pkgs.pinned.qbittorrent-nox.v4_6_5;
}
