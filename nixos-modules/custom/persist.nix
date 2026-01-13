{ config, inputs, lib, pkgs, ... }:
let
  homeManagerUserDirs = config.home-manager.users
  |> lib.mapAttrs (n: v: v.home.homeDirectory);

  partitionPathsForUser = user: paths: lib.partition (x:
    lib.hasPrefix homeManagerUserDirs.${user} x
  ) paths;

  # Taken from:
  # https://github.com/nix-community/impermanence/blob/cf507572c9eb6aada2ac865bc34ab421c827b658/nixos.nix#L59-L83
  # All persistent storage path submodule values zipped together into
  # one set. This includes paths from the Home Manager persistence
  # module and `users` submodules.
  allPersistentStoragePaths = let
    cfg = config.environment.persistence;
    # All enabled system paths
    nixos = lib.filter (v: v.enable) (lib.attrValues cfg);

    # Get the files and directories from the `users` submodules of
    # enabled system paths
    nixosUsers = lib.flatten (map lib.attrValues (lib.catAttrs "users" nixos));

    # Fetch enabled paths from all Home Manager users who have the
    # persistence module loaded
    homeManager =
      let
        paths = lib.flatten
          (lib.mapAttrsToList
            (_name: value:
              lib.attrValues (value.home.persistence or { }))
            config.home-manager.users or { });
      in
      lib.filter (v: v.enable) paths;
  in lib.zipAttrsWith (_: lib.flatten) (nixos ++ nixosUsers ++ homeManager);


  cfg = config.custom;
in
{
  imports = [
    inputs.impermanence.nixosModule
  ];

  options.custom = {
    persistDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mountpoint for persist subvolume";
    };
    prevDir = lib.mkOption {
      type = lib.types.str;
      default = "/prev";
      description = "Mountpoint for previous subvolume";
    };
    copyPersistPaths = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to automatically manage copying and deleting persistent files";
    };
    persistence = {
      directories = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [];
        description = "Directories to persist";
      };
      files = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [];
        description = "Files to persist";
      };
    };
    persistJSON = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to persist.json file";
    };
    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if config.custom.persistJSON != null
        then (builtins.fromJSON (lib.readFile config.custom.persistJSON)).files
        else [];
      description = "list of persistent files";
    };
    persistDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if config.custom.persistJSON != null
        then (builtins.fromJSON (lib.readFile config.custom.persistJSON)).directories
        else [];
      description = "list of persistent files";
    };
    persistTools = lib.mkOption {
      type = lib.types.attrs;
      default = {
        inherit homeManagerUserDirs partitionPathsForUser;
      };
      description = "some tools to help with persistence config";
    };
  };

  config = let
    filterUserPaths = paths: lib.foldl' (acc: x:
      (partitionPathsForUser x acc).wrong
    ) paths (lib.attrNames config.home-manager.users);

    nonUserPaths = {
      files = filterUserPaths cfg.persistFiles;
      directories = filterUserPaths cfg.persistDirectories;
    };
  in lib.mkIf (cfg.persistJSON != null || cfg.copyPersistPaths) {
    system.activationScripts = lib.mkIf cfg.copyPersistPaths {
      "copy-existing-persist-paths" = {
        deps = [
          "createPersistentStorageDirs"
          "specialfs"
        ];
        text = let
          persistFile = pkgs.writeText "persistent" (lib.concatStringsSep "\n" (lib.concatLists [
            (map (x: x.dirPath)  allPersistentStoragePaths.directories)
            (map (x: x.filePath) allPersistentStoragePaths.files)
          ]));
          useSnapper = ''${lib.boolToString config.custom.snapper.enable} && snapper -c persist ls > /dev/null'';
          removePath = pkgs.writeShellScript "removePath" ''
            path="$1"

            shopt -s dotglob

            if test -f "$path"; then
              rm "$path"
              rmdir \
                --parents \
                --ignore-fail-on-non-empty \
                "$(dirname "$path")"
              exit 0
            fi

            if test -d "$path"; then
              rm -r "$path"/*
              rmdir \
                --parents \
                --ignore-fail-on-non-empty \
                "$path"
              exit 0
            fi
          '';
          copyPath = let
            copyIfNotEmpty = pkgs.writeShellScript "copyIfNotEmpty" ''
              path="$1"

              shopt -s dotglob

              # path exists and is not an empty directory
              [ "$(ls -A "$path" 2> /dev/null)" ] || exit 0

              if test -d "$path"; then
                cp -a -rp --reflink "$path"/* "${config.custom.persistDir}/$path"
                exit 0
              fi

              if test -f "$path"; then
                cp -a -rp --reflink "$path" "${config.custom.persistDir}/$path"
                mv "$path" "$path.bak"
                exit 0
              fi
            '';
          in pkgs.writeShellScript "copyPath" ''
            path="$1"

            if ! mountpoint -q "$path"; then
              if ${useSnapper}; then
                snapper -c persist create --command "
                  ${copyIfNotEmpty} '$path'
                " -d "persist $path"
              else
                ${copyIfNotEmpty} "$path"
              fi
            fi
          '';
        in (pkgs.writeShellScript "copy-existing-persist-paths.sh" (
          ''
            PATH="${lib.makeBinPath ([
              pkgs.util-linux
              pkgs.coreutils
            ] ++ lib.optionals config.custom.snapper.enable [
              pkgs.snapper
            ])}"
          '' + "\n" +
          # Directories
          (
            lib.foldl' (acc: dir: acc + ''
              ${copyPath} "${dir.dirPath}"
            '') "" allPersistentStoragePaths.directories
          ) + "\n" +
          # Files
          (
            lib.foldl' (acc: file: acc + ''
              ${copyPath} "${file.filePath}"
            '') "" allPersistentStoragePaths.files
          ) +
          # Cleanup
          ''
            if test -f /etc/nixos/persistent; then
              comm -23 <(sort /etc/nixos/persistent) <(sort ${persistFile}) |
              while IFS= read -r path; do
                if ${useSnapper}; then
                  snapper -c persist create --command "
                    ${removePath} '${config.custom.persistDir}/$path'
                  " -d "remove $path"
                fi
                if test -f "$path.bak"; then
                  mv "$path.bak" "$path"
                fi
              done
            fi
          '' + ''
            cat ${persistFile} > /etc/nixos/persistent
          ''
        )).outPath;
      };
    };

    environment.persistence."${config.custom.persistDir}" = lib.foldl' (acc: x: {
      hideMounts = true;
      files = (acc.files or []) ++ (x.files or []);
      directories = (acc.directories or []) ++ (x.directories or []);
    }) {} [
      {
        inherit (nonUserPaths) files directories;
      }
      (lib.optionalAttrs cfg.copyPersistPaths {
        inherit (cfg.persistence) files directories;
      })
    ];
  };
}
