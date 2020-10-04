with import <nixpkgs> {};
let

  sources = import ./nix/sources.nix;

in pkgs.mkShell rec {
  
  buildInputs = with pkgs; [
    (import sources.home-manager {inherit pkgs;}).home-manager
    (import sources.nix-output-monitor {})
    jq
    niv
  ];

}

