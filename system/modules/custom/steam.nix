{ config, pkgs, lib, ... }:

let
  cfg = config.custom.steam;
  steam-custom = with pkgs; steam.override {
    extraLibraries = pkgs: [ gtk4 libadwaita config.hardware.opengl.package];
    extraPkgs = pkgs: [ mangohud ];
    extraEnv = {
      # https://github.com/ValveSoftware/Source-1-Games/issues/5043
      LD_PRELOAD = "$LD_PRELOAD:/run/current-system/sw/lib/libtcmalloc_minimal.so";
    };
  };
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
    programs.steam.enable = true;
    environment.systemPackages = let
      # games to make available on the command line
      games = [
        [ "elden-ring" "1234520" ]
        [ "noita"      "881100" ]
        [ "tf2"        "440" ]
      ];
    in with pkgs; [
      adwsteamgtk
      # https://github.com/ValveSoftware/Source-1-Games/issues/5043
      pkgsi686Linux.gperftools

      # game aliases
      (lib.pipe games [
        (map (game: let
          name = builtins.elemAt game 0;
          id = builtins.elemAt game 1;
        in {
          "${name}" = "steam -nochatui -nofriendsui -silent steam://rungameid/${id}";
        }))
        lib.mergeAttrs
        aliasToPackage
      ])
    ];
  };
}
