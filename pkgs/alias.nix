self: pkgs:
let
  lib = pkgs.lib;
in
{
  easyeffects = pkgs.callPackage ./easyeffects_7_2_5 { };

  adwsteamgtk = pkgs.adwsteamgtk.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/adwsteamgtk/fix_custom_css_permissions.patch
    ];
  });

  bottles = pkgs.bottles.override {
    removeWarningPopup = true;
  };

  jellyfin-mpv-shim = pkgs.jellyfin-mpv-shim.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/jellyfin-mpv-shim/pass.patch
    ];
  });

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  nix = (pkgs.lixPackageSets.latest.lix.overrideAttrs (old: {
    doCheck = false;
    doInstallCheck = false;
    patches = (old.patches or []) ++ [
      ./patches/nix/compadd.patch
    ];
  })).override {
    aws-sdk-cpp = null;
  };

  nixos-option = pkgs.nixos-option.override {
    nix = self.nix;
  };

  # https://github.com/NixOS/nixpkgs/issues/514113
  openldap = pkgs.openldap.overrideAttrs {
    doCheck = !pkgs.stdenv.hostPlatform.isi686;
  };

  updog = pkgs.updog.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/updog/username.patch
    ];
  });
}
