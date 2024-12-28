inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  inherit (inputs) get-flake;

  nix = inputs.lix.packages.x86_64-linux.nix.overrideAttrs (old: {
    doCheck = false;
    patches = [ ./nix.patch ];
  });

  nixos-option = pkgs.nixos-option.override {
    nix = pkgs.nix;
  };

  nil = inputs.nil.packages.x86_64-linux.nil;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };
}
