with import <nixpkgs> {};
let

  sources = import ./nix/sources.nix;

  devshell = import "${sources.devshell}/overlay.nix";

  pkgs = import <nixpkgs> {
    inherit system;
    overlays = [
      devshell
    ];
  };


in pkgs.mkDevShell {

  packages = with pkgs; [
    (import sources.home-manager {inherit pkgs;}).home-manager
    jq
    niv
  ];

}

