{ pkgs, lib, config, ... }:
let
  sources = import ./nix/sources.nix { };
  vencord = p: p.vencord.overrideAttrs (old: rec {
    version = lib.shortenRev sources.vencord.rev;
    src = sources.vencord;
    VENCORD_HASH = version;

    prePatch = ''
      cp ${./nix/package-lock.json} package-lock.json
      chmod +w package-lock.json
    '';

    npmDeps = p.fetchNpmDeps {
      inherit src prePatch;
      hash = sources.vencord.npmDepsHash;
    };
  });
in
{
  home.activation = let
    writeVesktopTheme = pkgs.writeShellScript "write-vesktop-theme" ''
      configFile="$HOME/.config/vesktop/settings/settings.json"
      newConfig="$(${pkgs.jq}/bin/jq -r '.plugins.ClientTheme.color = "${config.lib.stylix.scheme.base00}"' $configFile)"
      echo "$newConfig" > $configFile
    '';
  in {
    updateVesktopTheme = config.lib.dag.entryAfter ["writeBoundary"] ''
      run ${writeVesktopTheme}
    '';
  };

  home.packages = with pkgs; [
    (vesktop.override {
      vencord = vencord pkgs;
    })
    discord
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
