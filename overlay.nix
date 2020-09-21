self: super: rec {
  artwiz-lemon = super.callPackage ./pkgs/artwiz-lemon {};
  c = super.callPackage ./pkgs/c {};
  comma = super.callPackage ./pkgs/comma {};
  ix = super.callPackage ./pkgs/ix {};
  scientifica = super.callPackage ./pkgs/scientifica {};
  sent = super.sent.overrideAttrs (
    oldAttrs: {
      patches = [
        (
          builtins.fetchurl {
            url = "https://tools.suckless.org/sent/patches/inverted-colors/sent-invertedcolors-72d33d4.diff";
            sha256 = "10xs1a19wr3pjwiqfvvyc3zykf13bvvy6zvipa317036j1fn0gpb";
          }
        )
        (
          builtins.fetchurl {
            url = "https://tools.suckless.org/sent/patches/bilinear_scaling/sent-bilinearscaling-1.0.diff";
            sha256 = "1xhyhdl88jc2g6m77amw278waw1ahwg02y2c21sg77m41ksfzwb5";
          }
        )
      ];
    }
  );
}

