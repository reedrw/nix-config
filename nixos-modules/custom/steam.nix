{ config, pkgs, lib, ... }:

let
  cfg = config.custom.steam;
  steam-custom = with pkgs; steam.override {
    extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.graphics.package];
    extraPkgs = pkgs: [ mangohud steamtinkerlaunch winetricks ];
    extraEnv = {
      # https://github.com/ValveSoftware/Source-1-Games/issues/5043
      LD_PRELOAD = "$LD_PRELOAD:/run/current-system/sw/lib/libtcmalloc_minimal.so";
    };
  };
  optionalApply = bool: f: x:
    if bool then f x else x;
in
{
  options.custom.steam = {
    enable = lib.mkEnableOption "Steam";

    mullvad-exclude = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Exclude Steam from Mullvad VPN";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      # package = steam-custom;
      package = with pkgs; emptyDirectory // {
        override = (x: optionalApply cfg.mullvad-exclude mullvadExclude steam-custom // {
          run = steam-custom.run;
        });
      };
    };
    environment.systemPackages = let
      # games to make available on the command line
      games = [
        [ "elden-ring" "1234520" ]
        [ "noita"      "881100" ]
        [ "tf2"        "440" ]
      ];
    in with pkgs; [
      # https://github.com/ValveSoftware/Source-1-Games/issues/5043
      pkgsi686Linux.gperftools

      # game aliases
      (games
        |> (map (game: let
          name = builtins.elemAt game 0;
          id = builtins.elemAt game 1;
        in {
          "${name}" = "steam -nochatui -nofriendsui -silent steam://rungameid/${id}";
        }))
        |> lib.mergeAttrsList
        |> aliasToPackage
      )
    ];
  };
}
