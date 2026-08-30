self: pkgs:
let
  inherit (pkgs) lib;
in
{
  # last gtk easyeffects version
  easyeffects = pkgs.mv.version "easyeffects" "7.2.5";

  adwsteamgtk = pkgs.adwsteamgtk.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/adwsteamgtk/fix_custom_css_permissions.patch
    ];
  });

  bottles = pkgs.bottles.override {
    removeWarningPopup = true;
  };

  librepods = pkgs.librepods.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/librepods/pa-eol-deadlock.patch
    ];
  });

  # Scroll 5 lines per mouse-wheel tick in fullscreen mode (matches tmux
  # scrollback speed); upstream hardcodes 1 and exposes no option.
  pi-coding-agent = pkgs.mv.tip.pi-coding-agent.overrideAttrs (old: {
    # Scroll 5 lines per mouse-wheel tick in fullscreen mode (matches tmux
    # scrollback speed); upstream hardcodes 1 and exposes no option. Also drop
    # the blank line ToolExecutionComponent puts above every self-shell tool
    # row, so collapsed glance rows stack tightly, Claude Code style.
    postFixup = (old.postFixup or "") + ''
      file="$out/lib/node_modules/pi-monorepo/node_modules/@earendil-works/pi-tui/dist/tui-alt-screen.js"
      grep -q 'options.wheelScrollLines ?? 1' "$file"
      sed -i 's/options.wheelScrollLines ?? 1/options.wheelScrollLines ?? 5/' "$file"
      exec="$out/lib/node_modules/pi-monorepo/dist/modes/interactive/components/tool-execution.js"
      grep -q 'lines.push("")' "$exec"
      sed -i '/if (contentLines.length > 0) {/ { n; /lines.push("")/d }' "$exec"
    '';
  });

  jellyfin-mpv-shim = pkgs.jellyfin-mpv-shim.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/jellyfin-mpv-shim/pass.patch
    ];
  });

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  nix = (pkgs.lixPackageSets.latest.lix.overrideAttrs (old: {
    doCheck = false;
    doInstallCheck = false;
    patches = (old.patches or []) ++ [
      ./patches/nix/compadd.patch
    ];
  })).override {
    aws-sdk-cpp = null;
  };

  nixos-option = pkgs.nixos-option.override {
    inherit (self) nix;
  };

  updog = pkgs.updog.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/updog/username.patch
    ];
  });
}
