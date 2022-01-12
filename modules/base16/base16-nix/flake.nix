{
  description = "Base16-template builder for nix.";

  inputs.nixpkgs.url = "nixpkgs/release-21.05";

  outputs = { self, nixpkgs }@inputs:
    with nixpkgs.legacyPackages."x86_64-linux"; rec {
      # Home-Manager Module
      hmModule = ./base16.nix;

      packages.x86_64-linux.update-base16 = (let
        mkScript = { name, file, env ? [ ] }:
          writeTextFile {
            name = "${name}";
            executable = true;
            destination = "/bin/${name}";
            text = ''
              for i in ${lib.concatStringsSep " " env}; do
                export PATH="$i/bin:$PATH"
              done
              exec ${bash}/bin/bash ${file} $@
            '';
          };
      in mkScript rec {
        name = "update-base16";
        env = [ curl nix-prefetch-git gnused jq ];
        file = writeTextFile {
          name = "${name}.sh";
          executable = true;
          text = ''
            generate_sources () {
              out=$1
              curl "https://raw.githubusercontent.com/chriskempson/base16-$out-source/master/list.yaml"\
              | sed -nE "s~^([-_[:alnum:]]+): *(.*)~\1 \2~p"\
              | while read name src; do
                  echo "{\"key\":\"$name\",\"value\":"
                  nix-prefetch-git $src
                  echo "}"
                done\
              | jq -s ".|del(.[].value.date)|from_entries"\
              > $out.json
            }
            generate_sources templates &
            generate_sources schemes &
            wait
          '';
        };
      });

      defaultPackage.x86_64-linux = packages.x86_64-linux.update-base16;

      devShell.x86_64-linux = mkShell {
        buildInputs = [ packages.x86_64-linux.update-base16 ];
      };
    };
}
