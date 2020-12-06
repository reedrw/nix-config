{ config, lib, pkgs, ... }:
let

  myFirefox = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    nixExtensions = (import ./sources.nix pkgs);
  };

in
{

  home.packages = [ myFirefox ];

}
