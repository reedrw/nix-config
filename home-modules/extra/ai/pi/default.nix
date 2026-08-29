{
  pkgs,
  lib,
  ...
}:
let
  # Mirrors home-manager's programs/pi-coding-agent module (not yet in release-26.05):
  # extraPackages wrap + declarative settings.json with pi packages.
  jsonFormat = pkgs.formats.json { };


  # Everything in ./plugins is installed automatically: *.ts files as
  # extensions, everything else (vendored or pinned npm — see plugins/) as
  # local-dir packages. Install/uninstall by editing the plugins dir or
  # pins.json (then run its update.sh).
  # callPackage wraps its result with override helpers; strip them so the set
  # is uniformly iterable.
  plugins = builtins.removeAttrs (pkgs.callPackage ./plugins { }) [
    "override"
    "overrideDerivation"
  ];

  extensionPlugins = lib.filterAttrs (_: p: p.passthru.piKind == "extension") plugins;
  dirPlugins = lib.filterAttrs (_: p: p.passthru.piKind == "package") plugins;

  extensionFiles = lib.listToAttrs (
    lib.mapAttrsToList (name: plugin: {
      name = ".pi/agent/extensions/${name}.ts";
      value = {
        force = true;
        source = "${plugin}/${name}.ts";
      };
    }) extensionPlugins
  );

  dirPackageFiles = lib.listToAttrs (
    lib.mapAttrsToList (name: plugin: {
      name = ".pi/agent/${name}";
      value = {
        force = true;
        source = plugin;
      };
    }) dirPlugins
  );
in
{
  home = {
    # nix-locate (for nix-comma.ts) is already on PATH via home.packages in
    # home-modules/core/comma/default.nix, so no wrapper needed.
    packages = [ pkgs.mv.tip.pi-coding-agent ];

    file = extensionFiles // dirPackageFiles // {
      ".pi/agent/settings.json" = {
        force = true;
        source = jsonFormat.generate "pi-settings.json" {
          lastChangelogVersion = "0.84.2";
          defaultProvider = "openrouter";
          defaultModel = "z-ai/glm-5.3-flash";
          defaultThinkingLevel = "high";
          theme = "dark";
          packages = lib.mapAttrsToList (name: _: "./${name}") dirPlugins;
          # image-history.ts renders tool-result images inside the tool box via
          # kitty placeholders; disable pi's built-in Image path, which draws
          # outside the box (and is tmux-disabled anyway).
          terminal.showImages = false;
        };
      };
    };
  };

  custom.persistence.directories = [ ".pi" ];
}
