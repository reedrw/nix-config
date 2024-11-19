inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  nix = inputs.lix.packages.x86_64-linux.nix;

  nixos-option = pkgs.nixos-option.override {
    nix = pkgs.nix;
  };

  nil = inputs.nil.packages.x86_64-linux.nil;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  # TODO: remove on next release
  qbittorrent-nox = pkgs.pkgs-unstable.qbittorrent-nox;
}
