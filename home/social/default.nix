{ pkgs, ... }:
let
  inherit (pkgs.fromBranch) unstable;

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
    (wrapEnv tdesktop {
      XDG_CURRENT_DESKTOP = "gnome";
    })
    (pinned.vesktop.v1_5_1.override {
      vencord = vencord unstable;
    })
    cinny-desktop
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };
}
