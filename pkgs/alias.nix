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

  # https://animebytes.tv/rules/clients
  # wait for AB to allowed qBittorrent v5
  qbittorrent-nox = pkgs.pinned.qbittorrent-nox.v4_6_7;
}
