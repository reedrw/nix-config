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

  chromium-no-apng-pkgs = pkgs.importNixpkgs sources.pr-274386 { };
in
{
  home.packages = with pkgs; [
    tdesktop
    (master.vesktop.override {
      vencord = vencord master;
      electron = chromium-no-apng-pkgs.electron;
    })
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
