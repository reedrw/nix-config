let
  sources = import ./nix/sources.nix;

  hm-overlay = self: super: {
    home-manager = super.callPackage "${sources.home-manager}/home-manager" { };
  };

  pre-commit = self: super: {
    pre-commit = (import
      (pkgs.fetchzip {
        url = "https://github.com/nixos/nixpkgs/archive/7138a338b58713e0dea22ddab6a6785abec7376a.zip";
        sha256 = "1asgl1hxj2bgrxdixp3yigp7xn25m37azwkf3ppb248vcfc5kil3";
      })
      { }).gitAndTools.pre-commit;
  };

  pkgs = import sources.nixpkgs {
    overlays = [
      hm-overlay
      pre-commit
    ];
  };

  fromYaml = yamlFile:
    let
      jsonFile = pkgs.runCommandNoCC "yaml-str-to-json"
        {
          nativeBuildInputs = [ pkgs.remarshal ];
          value = builtins.readFile yamlFile;
          passAsFile = [ "value" ];
        } ''
        yaml2json "$valuePath" "$out"
      '';
    in
    builtins.fromJSON (builtins.readFile "${jsonFile}");

  resolveKey = key:
    let
      attrs = builtins.filter builtins.isString (builtins.split "\\." key);
    in
    builtins.foldl' (sum: attr: sum.${attr}) pkgs attrs;

  # transform the env vars into bash instructions
  envToBash = with pkgs; env:
    builtins.concatStringsSep "\n"
      (lib.mapAttrsToList
        (k: v: "export ${k}=${lib.escapeShellArg (toString v)}")
        env
      )
  ;

  shell = fromYaml ./shell.yaml;

in
pkgs.mkShell {
  name = "${shell.name}";

  buildInputs = map resolveKey (shell.packages or [ ]);

  shellHook = ''
    ${envToBash shell.env}
    ${shell.run}
  '';

}
