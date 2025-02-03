self: pkgs:
let
  lib = pkgs.lib;
in
{
  # hasMainProgram :: Package -> Bool
  ########################################
  # Given a package, return true if the package has a meta.mainProgram attribute.
  # Ex.
  # hasMainProgram hello
  #
  # Returns:
  # true
  hasMainProgram = x: builtins.hasAttr "mainProgram" x.meta;

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

  # versionConditionalOverride :: String -> Package -> Package -> Package
  ########################################################################
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
    else lib.warn "versionConditionalOverride: ${package.name} is already at version ${package.version}. No override applied."
         package;

  # matchPackage :: String -> Package
  ########################################
  # Given a package name, return the corresponding package from nixpkgs.
  matchPackage = pkgName:
    builtins.foldl' (a: x: a."${x}") pkgs (lib.splitString "." pkgName);

  # writeNixShellScript :: String -> String -> Package
  ########################################################
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
      runtimeInputs = text
        # Get the second line of the script, which contains the packages
        |> lib.splitString "\n"
        |> (x: lib.elemAt x 1)
        # Get the packages from the second line
        |> lib.splitString " -p "
        |> (x: lib.elemAt x 1)
        # Convert the package names to nixpkgs packages
        |> lib.splitString " "
        |> map self.matchPackage;
    in
    pkgs.writeShellApplication {
      inherit name text runtimeInputs;
      meta.mainProgram = name;
    };

  # writeXonshNixShellScript :: String -> String -> Package
  ############################################################
  # Given a name and the text of a xonsh script with nix-shell shebang, return a package that
  # has the packages specfied in the shebang as dependencies.
  # Ex.
  # writeXonshNixShellScript "hello-world" (builtins.readFile ./hello-world.xsh)
  #
  # Contents of ./hello-world.xsh:
  # #!/usr/bin/env nix-shell
  # #! nix-shell -i xonsh -p hello
  # echo "Hello, world!"
  writeXonshNixShellScript = name: text:
    let
      runtimeInputs = text
        # Get the second line of the script, which contains the packages
        |> lib.splitString "\n"
        |> (x: lib.elemAt x 1)
        # Get the packages from the second line
        |> lib.splitString " -p "
        |> (x: lib.elemAt x 1)
        # Convert the package names to nixpkgs packages
        |> lib.splitString " "
        |> map self.matchPackage;
    in
    self.writeXonshApplication {
      inherit name text runtimeInputs;
      meta.mainProgram = name;
    };

  # matchPackageCommand :: String -> String
  ########################################
  # Given a command starting with a package name, return the
  # string with the package name replaced with the path to the package.
  # Ex.
  # matchPackageCommand "hello --world"
  #
  # Returns:
  # "/nix/store/qyfq3ivjq7xl0kaqg4lrhcfh9zbjkqsc-hello-2.12.1/bin/hello --world"
  matchPackageCommand = command:
    let
      parts = lib.splitString " " command;
      package = self.matchPackage (builtins.head parts);
    in
    builtins.concatStringsSep " " ([ (lib.getExe package) ] ++ builtins.tail parts);

  # wrapPackage :: Package -> (String -> String) -> Package
  ##########################################################
  # Wrap a package's main program with a shell script. The shell script is generated by the function
  # passed as the second argument. The function is passed the path to the unwrapped binary.
  #
  # Ex.
  # wrapPackage hello (x: "echo Store path: ${x}")
  #
  # $ hello
  # Store path: /nix/store/qyfq3ivjq7xl0kaqg4lrhcfh9zbjkqsc-hello-2.12.1/bin/hello
  wrapPackage = package: f: let
    binary = package.meta.mainProgram or (
    lib.warn ''wrapPackage: package "${package.name}" does not have the meta.mainProgram attribute.''
    (builtins.parseDrvName package.name).name);
  in pkgs.symlinkJoin {
    inherit (package) name;
    paths = [ package ];
    postBuild = ''
      echo "Wrapping ${binary}"
      rm "$out/bin/${binary}"
      cat << _EOF > $out/bin/${binary}
      ${f "${package}/bin/${binary}"}
      _EOF
      chmod 555 "$out/bin/${binary}"
    '';

    meta.mainProgram = binary;
  };

  # wrapEnv :: Package -> AttrSet -> Package
  ###########################################
  # Given a package and an attribute set containing environment variables, override the package
  # to include the environment variables at runtime.
  # Ex.
  # wrapEnv hello { FOO = "bar"; }
  wrapEnv = package: env: self.wrapPackage package (x: ''
    #! ${pkgs.runtimeShell} -e
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${v}") env)}
    exec ${x} "\$@"
  '');

  # writeXonshApplication :: { ... } -> Package
  ################################################
  # Return a package that runs a xonsh script with dependencies specified in runtimeInputs.aliasToPackage
  # Ex.
  # writeXonshApplication {
  #   name = "hello-world";
  #   text = builtins.readFile ./hello-world.xsh;
  #   runtimeInputs = [ pkgs.hello ];
  # }
  #
  writeXonshApplication = {
    name,
    text,
    runtimeInputs ? [],
    meta ? {}
  }: pkgs.writeTextFile {
    inherit name meta;
    executable = true;
    destination = "/bin/${name}";
    allowSubstitutes = true;
    preferLocalBuild = false;
    text = ''
      #!${pkgs.xonsh}/bin/xonsh
    '' + lib.optionalString (runtimeInputs != []) ''
      $PATH.prepend("${lib.makeBinPath runtimeInputs}");
    '' + ''
      ${text}
    '';
  };

  # writeXonshScript :: String -> String -> Package
  ####################################################
  # Given a name and the text of a xonsh script, return a package of the xonsh script.
  # Ex.
  # writeXonshScript "hello-world" (builtins.readFile ./hello-world.xsh)
  #
  # Contents of ./hello-world.xsh:
  # #!/usr/bin/env xonsh
  # echo "Hello, world!"
  writeXonshScript = name: text:
    pkgs.writeTextFile {
      inherit name;
      text = ''
        !#${pkgs.xonsh}/bin/xonsh
        ${text}
      '';
    };

  # mullvadExclude :: Package -> Package
  ########################################
  # Given a package, wrap the package with mullvad-exclude.
  mullvadExclude = package: self.wrapPackage package (x: ''
    #! ${pkgs.runtimeShell} -e
    if [[ -f /run/wrappers/bin/mullvad-exclude ]]; then
      exec /run/wrappers/bin/mullvad-exclude ${x} "\$@"
    else
      exec ${x} "\$@"
    fi
  '');
}
