self: super: rec {
  artwiz-lemon = super.callPackage ./pkgs/artwiz-lemon { };
  c = super.callPackage ./pkgs/c { };
  comma = super.callPackage ./pkgs/comma { };
  scientifica = super.callPackage ./pkgs/scientifica { };
}
