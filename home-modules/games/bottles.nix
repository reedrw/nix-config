{ pkgs, ... }:

{
  home.packages = [
    pkgs.bottles
    (pkgs.aliasToPackage {
      kh3 = "bottles-cli run -p 'Kingdom Hearts III' -b 'Kingdom Hearts III'";
    })
  ];
}
