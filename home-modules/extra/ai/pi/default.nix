{
  pkgs,
  lib,
  ...
}:
let
  # Mirrors home-manager's programs/pi-coding-agent module (not yet in release-26.05):
  # extraPackages wrap + declarative settings.json with pi packages, which pi
  # auto-installs on startup when missing or version-mismatched.
  jsonFormat = pkgs.formats.json { };
  piPackage = pkgs.wrapPackage pkgs.mv.tip.pi-coding-agent (x: ''
    export PATH="$PATH:${lib.makeBinPath [ pkgs.nodejs ]}"
    exec ${x} "$@"
  '');
in
{
  home = {
    packages = [ piPackage ];

    file = {
      ".pi/agent/settings.json" = {
        force = true;
        source = jsonFormat.generate "pi-settings.json" {
          lastChangelogVersion = "0.84.2";
          defaultProvider = "openrouter";
          defaultModel = "z-ai/glm-5.3-flash";
          defaultThinkingLevel = "high";
          theme = "dark";
          packages = [ ];
        };
      };

      ".pi/agent/extensions/co-author.ts" = {
        force = true;
        source = ./co-author.ts;
      };

      ".pi/agent/extensions/statusline.ts" = {
        force = true;
        source = ./statusline.ts;
      };

      ".pi/agent/extensions/exit-alias.ts" = {
        force = true;
        text = ''
          import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

          export default function (pi: ExtensionAPI) {
            pi.registerCommand("exit", {
              description: "Exit pi (alias for /quit)",
              handler: async (_args, ctx) => {
                ctx.shutdown();
              },
            });
          }
        '';
      };
    };
  };

  custom.persistence.directories = [ ".pi" ];
}
