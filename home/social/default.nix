{ pkgs, lib, ... }:
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
  home.packages = with pkgs; [
    (wrapEnv tdesktop {
      XDG_CURRENT_DESKTOP = "gnome";
    })
    (vesktop.override {
      vencord = vencord pkgs;
    })
    discord
  ];

  xdg.configFile = {
    "discord/settings.json".source = ./discord-settings.json;
    "discordcanary/settings.json".source = ./discord-settings.json;
  };

  # doesn't do anything on i3, but needed for Telegram to close without minimizing
  # https://github.com/telegramdesktop/tdesktop/issues/27190#issuecomment-1840780300
  dconf.settings = {
    "org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
  };
}
