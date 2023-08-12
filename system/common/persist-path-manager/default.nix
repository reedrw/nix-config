{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (symlinkJoin {
      name = "persist-path-manager";
      paths = [
        # $out/bin/persist
        (writeNixShellScript "persist" (builtins.readFile ./persist))

        # $out/share/zsh/site-functions/_persist
        (stdenv.mkDerivation {
          name = "persist-path-manager-zsh";
          src = ./.;
          installPhase = ''
            mkdir -p $out/share/zsh/site-functions
            cp -r ./_persist $out/share/zsh/site-functions
          '';
        })
      ];
    })
  ];
}
