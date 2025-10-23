inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  bottles = pkgs.bottles.override {
    removeWarningPopup = true;
  };

  gh = pkgs.pkgs-unstable.gh;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  nil = inputs.nil.packages.x86_64-linux.nil;

  nix = inputs.lix.packages.x86_64-linux.nix.overrideAttrs (old: {
    doCheck = false;
    patches = [ ./patches/nix/compadd.patch ];
  });

  nixos-option = pkgs.nixos-option.override {
    nix = pkgs.nix;
  };

  updog = pkgs.updog.overrideAttrs (old: {
    patches = [ ./patches/updog/username.patch ];
  });
}
