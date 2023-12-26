self: pkgs:
let
  lib = pkgs.lib;
in
{
  ldp = pkgs.callPackage ./ldp { };
  persist-path-manager = pkgs.callPackage ./persist-path-manager { };

  # aliasToPackage :: AttrSet -> Package
  ########################################
  # Takes an attribute set and converts into shell scripts to act as "global aliases"
  # Ex.
  # aliasToPackage {
  #   str = ''${gcc}/bin/strings "$@"'';
  #   tb = ''${netcat}/bin/nc termbin.com 9999 "$@"'';
  # }
  #
  # Returns:
  # /nix/store/l0x3s11938c2drxq19sp8hdmz4ig2nj1-alias-str-tb
  # └── bin
  #    ├── str -> /nix/store/bmajpd6q4j1g14s5vvg6li94rln9w3kp-str/bin/str
  #    └── tb -> /nix/store/4q5d9z7r4a1qvpd6klblksrm0racx6px-tb/bin/tb
  aliasToPackage = alias:
    let
      name = builtins.concatStringsSep "-"  ([ "alias" ] ++ (builtins.attrNames alias));
      paths = lib.mapAttrsToList pkgs.writeShellScriptBin alias;
      numAliases = builtins.length paths;
    in
    if numAliases < 2
    then builtins.head paths
    else pkgs.symlinkJoin { inherit name paths; };

  # binPath :: Package -> String
  ########################################
  # Takes a package as input and returns the path to the binary with the same name.
  # Ex.
  # binPath bat
  #
  # Returns:
  # "/nix/store/vkbfya4qhmzykw6fqs409q5ajdrnhzlq-bat-0.22.1/bin/bat"
  binPath = package: let
    name = (builtins.parseDrvName package.name).name;
  in
    "${package}/bin/${name}";

  # versionConditionalOverride :: String -> Package -> Package -> Package
  ########################################
  # Override a package until next release. Takes current version, package, and override as arguments.
  # Ex.
  # versionConditionalOverride "1.4.1" distrobox
  #   (distrobox.overrideAttrs (
  #     old: {
  #       src = pkgs.fetchFromGitHub {
  #         owner = "89luca89";
  #         repo = "distrobox";
  #         rev = "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9";
  #         sha256 = "nIqkptnP3fOviGcm8WWJkBQ0NcTE9z/BNLH/ox6qIoA=";
  #       };
  #     }
  #   ))
  versionConditionalOverride = version: package: override:
    if builtins.compareVersions package.version version < 1
    then override
    else package;

  # shortenRev :: String -> String
  ########################################
  # Shortens a git commit hash to the first 7 characters
  # Ex.
  # shortenRev "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9"
  #
  # Returns:
  # "acb36a4"
  shortenRev = rev: builtins.substring 0 7 rev;

  # buildFromNivSource :: Package -> AttrSet -> Package
  ########################################
  # Given a package an niv sources set, overrides package to build from niv source with same name.
  # Ex.
  # `buildFromNivSource i3 sources`
  # will build i3 from sources.i3
  buildFromNivSource = package: sources:
  let
    name = (builtins.parseDrvName package.name).name;
    src = sources."${name}";
    version = self.shortenRev src.rev;
  in
    package.overrideAttrs {
      inherit version src;
    };

  # buildFromNivSourceUntilVersion :: String -> Package -> AttrSet -> Package
  ########################################
  # Given the current version of a package, the package itsef, and a niv sources set, build from
  # niv sources until the version of the package is newer than the specified version.
  # Ex.
  # buildFromNivSourceUntilVersion "1.4.1" distrobox sources
  buildFromNivSourceUntilVersion = version: package: sources:
    self.versionConditionalOverride version package
      (self.buildFromNivSource package sources);

  # importNixpkgs :: AttrSet -> AttrSet
  ########################################
  # Given a nixpkgs source as arugment, import it with the current config.
  importNixpkgs = nixpkgs: {
    config ? pkgs.config,
    overlays ? pkgs.overlays,
    system ? pkgs.system }:
    import nixpkgs { inherit config overlays system; };

  # writeNixShellScript :: String -> String -> Package
  ########################################
  # Given a name and the text of a shell script with nix-shell shebang, return a package that
  # has the packages specfied in the shebang as dependencies.
  # Ex.
  # writeNixShellScript "hello-world" (builtins.readFile ./hello-world)
  #
  # Contents of ./hello-world:
  # #!/usr/bin/env nix-shell
  # #! nix-shell -i bash -p hello
  # hello
  writeNixShellScript = name: text:
    let
      # Get the second line of the script, which contains the packages
      secondLine = builtins.elemAt (lib.splitString "\n" text) 1;
      # Get the packages from the second line
      packageList = builtins.elemAt (lib.splitString " -p " secondLine) 1;
      # Convert the package names to nixpkgs packages
      runtimeInputs = map (x: pkgs."${x}") (lib.splitString " " packageList);
    in
    pkgs.writeShellApplication {
      inherit name text runtimeInputs;
    };

  # listDirectory :: Path -> [Path]
  ########################################
  # Given a path to a directory, return a list of everything in that directory
  # relative to the calling nix file.
  listDirectory = path:
    builtins.map (x: path + "/${x}") (builtins.attrNames (builtins.readDir path));

  # mullvadExclude :: Package -> Package
  ########################################
  # Given a package, wrap all the non-hidden binaries in the package with mullvad-exclude.
  mullvadExclude = package:
  let
    # get a list of all the binaries provided by the package
    allBinaries = builtins.attrNames (builtins.readDir ("${package}/bin"));
    # remove binaries which start with a .
    binaries = builtins.filter (x: (builtins.substring 0 1 x) != ".") allBinaries;

  in pkgs.symlinkJoin {
    name = "${package.name}-mullvad-exclude";
    paths = [ package ];
    postBuild = ''
      for binary in ${builtins.concatStringsSep " " binaries}; do
        echo "Wrapping $binary with mullvad-exclude"
        rm "$out/bin/$binary"
        cat << _EOF > $out/bin/$binary
      #! ${pkgs.runtimeShell} -e
      if [[ -f /run/wrappers/bin/mullvad-exclude ]]; then
        exec /run/wrappers/bin/mullvad-exclude ${package}/bin/$binary "\$@"
      else
        exec ${package}/bin/$binary "\$@"
      fi
      _EOF
        chmod 555 "$out/bin/$binary"
      done
    '';
  };

  # mergeAttrs :: [AttrSet] -> AttrSet
  ########################################
  # Takes a list of attribute sets and merges them into one using lib.recursiveUpdate
  # Ex.
  # mergeAttrs [
  #   { a = 1; b = 2; }
  #   { b = 3; c = 4; }
  # ]
  #
  # Returns:
  # { a = 1; b = 3; c = 4; }
  mergeAttrs = attrs: lib.foldl' lib.recursiveUpdate {} attrs;

  # mkSimpleHMService :: String -> String -> AttrSet
  ########################################
  # Given a name and a command, return a simple service that runs the command.
  mkSimpleHMService = name: ExecStart: {
    ${name} = {
      Unit = {
        Description = "${name}";
        After = [ "graphical.target" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        inherit ExecStart;
        Restart = "on-failure";
        RestartSec = 5;
        Type = "simple";
      };
    };
  };

  # optionalApply :: Bool -> (a -> b) -> a -> b
  ########################################
  # Given a boolean, a function, and a value, apply the function to the value if the boolean is true.
  # Ex.
  # optionalApply true (x: x + 1) 1
  #
  # Returns:
  # 2
  optionalApply = bool: f: x:
    if bool then f x else x;
}
