{ pkgs, ... }:
let
  inherit (pkgs.fromBranch) master;

  sources = import ./nix/sources.nix { };
  vencord = p: p.vencord.overrideAttrs (old: rec {
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
in
{
  home.packages = with pkgs; [
    tdesktop
    # (master.discord.override {
    #   vencord = vencord master;
    #   withVencord = true;
    #   nss = nss_latest;
    # })
    (vesktop.override {
      vencord = vencord master;
    })
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
