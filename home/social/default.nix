{ pkgs, inputs, ... }:
let
  sources = import ./nix/sources.nix { };
  vencordPkgs = pkgs.importNixpkgs inputs.master {
    overlays = [ (_: p: {
      vencord = p.vencord.overrideAttrs (old: rec {
        version = pkgs.shortenRev sources.vencord.rev;
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
    })];
  };
in
{
  home.packages = with pkgs; [
    tdesktop
    (vencordPkgs.discord.override {
      withVencord = true;
      nss = nss_latest;
    })
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
