self: super: rec {
  artwiz-lemon = super.callPackage ./nix-home/pkgs/artwiz-lemon {};
  c = super.callPackage ./nix-home/pkgs/c {};
  comma = super.callPackage ./nix-home/pkgs/comma {};
  ix = super.callPackage ./nix-home/pkgs/ix {};
  scientifica = super.callPackage ./nix-home/pkgs/scientifica {};
}

