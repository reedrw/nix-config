{ osConfig, lib, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: ./${x});

  config = lib.mkIf osConfig.programs.dconf.enable {
    custom.persistence.directories = [
      ".config/dconf"
    ];
  };
}
