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
          # pi-image-view is vendored and loaded
          # from a local path; relative paths resolve against ~/.pi/agent.
          packages = [
            "./pi-image-view"
          ];
          # image-history.ts renders tool-result images inside the tool box via
          # kitty placeholders; disable pi's built-in Image path, which draws
          # outside the box (and is tmux-disabled anyway).
          terminal.showImages = false;
        };
      };

      ".pi/agent/extensions/co-author.ts" = {
        force = true;
        source = ./co-author.ts;
      };

      ".pi/agent/pi-image-view" = {
        force = true;
        source = ./pi-image-view;
      };

      ".pi/agent/extensions/image-history.ts" = {
        force = true;
        source = ./image-history.ts;
      };

      ".pi/agent/extensions/statusline.ts" = {
        force = true;
        source = ./statusline.ts;
      };

      ".pi/agent/extensions/clear-alias.ts" = {
        force = true;
        text = ''
          import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

          export default function (pi: ExtensionAPI) {
            pi.registerCommand("clear", {
              description: "Start a new session (alias for /new)",
              handler: async (_args, ctx) => {
                await ctx.waitForIdle();
                await ctx.newSession();
              },
            });
          }
        '';
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
