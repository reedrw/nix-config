with import <nixpkgs> {};
let

  sources = import ./nix-home/nix/sources.nix;

in pkgs.mkShell rec {
  
  buildInputs = with pkgs; [
    (import sources.home-manager {inherit pkgs;}).home-manager
    niv
  ];

}

