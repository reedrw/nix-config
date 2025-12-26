inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  bottles = pkgs.bottles.override {
    removeWarningPopup = true;
  };

  jellyfin-mpv-shim = pkgs.jellyfin-mpv-shim.overrideAttrs (old: {
    patches = [ ./patches/jellyfin-mpv-shim/pass.patch ];
  });

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

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
