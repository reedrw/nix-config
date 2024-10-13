inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  nix = inputs.lix.packages.x86_64-linux.nix;

  nil = inputs.nil.packages.x86_64-linux.nil;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  # https://github.com/NixOS/nixpkgs/pull/322548
  qbittorrent-nox = if builtins.hasAttr "mainProgram" pkgs.qbittorrent-nox.meta
    then lib.warn "qbittorrent-nox mainProgram fixed. PR should be merged." pkgs.pinned.qbittorrent-nox.v5_0_0
    else pkgs.pinned.qbittorrent-nox.v5_0_0;
}
