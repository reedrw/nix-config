self: super: rec {
  artwiz-lemon = super.callPackage ./pkgs/artwiz-lemon {};
  c = super.callPackage ./pkgs/c {};
  comma = super.callPackage ./pkgs/comma {};
  ix = super.callPackage ./pkgs/ix {};
  scientifica = super.callPackage ./pkgs/scientifica {};
}

