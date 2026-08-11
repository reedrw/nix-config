self: pkgs:
let
  inherit (pkgs) lib;
in
{
  # last gtk easyeffects version
  easyeffects = pkgs.mv.version "easyeffects" "7.2.5";

  adwsteamgtk = pkgs.adwsteamgtk.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/adwsteamgtk/fix_custom_css_permissions.patch
    ];
  });

  bottles = pkgs.bottles.override {
    removeWarningPopup = true;
  };

  librepods = pkgs.librepods.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/librepods/pa-eol-deadlock.patch
    ];
  });

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
    inherit (self) nix;
  };

  updog = pkgs.updog.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/updog/username.patch
    ];
  });
}
