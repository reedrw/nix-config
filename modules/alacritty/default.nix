{ inputs, config, pkgs, ... }:
let
  tmuxconf = builtins.toFile "tmuxconf" ''
    set -g status off
    set -g destroy-unattached on
    set -g mouse on
    set -g default-terminal 'tmux-256color'
    set -ga terminal-overrides ',alacritty:RGB'
    set -s escape-time 0
    set -g history-limit 10000
  '';
in
{

  home.packages = [ pkgs.scientifica ]; # font

  programs.alacritty = {
    enable = true;
    # select-term script broken by bug introduced at commit 0e418bc2f761617455cc58aaabc375055dfe4284
    # https://github.com/alacritty/alacritty/issues/6884
    package = with pkgs; versionConditionalOverride "0.13" alacritty (
      alacritty.overrideAttrs (old: rec {
        src = fetchFromGitHub {
          owner = "alacritty";
          repo = "alacritty";
          rev = "578e08486dfcdee0b2cd0e7a66752ff50edc46b8";
          sha256 = "sha256-FVbgQ7KDJgl3lrlJIvykus7MPBKlp5e/Gaj0UYUlg7Y=";
        };

        cargoDeps = rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
        };
      })
    );
    # package = with pkgs; alacritty.overrideAttrs (old: rec {
    #   src = inputs.alacritty;
    #   cargoDeps = rustPlatform.importCargoLock {
    #     lockFile = "${src}/Cargo.lock";
    #   };
    #   nativeBuildInputs = old.nativeBuildInputs ++ [
    #     scdoc
    #   ];
    #
    #   postInstall = let
    #     rpathLibs = [
    #       expat
    #       fontconfig
    #       freetype
    #       libGL
    #       xorg.libX11
    #       xorg.libXcursor
    #       xorg.libXi
    #       xorg.libXrandr
    #       xorg.libXxf86vm
    #       xorg.libxcb
    #       libxkbcommon
    #       wayland
    #     ];
    #   in ''
    #     install -D extra/linux/Alacritty.desktop -t $out/share/applications/
    #     install -D extra/linux/org.alacritty.Alacritty.appdata.xml -t $out/share/appdata/
    #     install -D extra/logo/compat/alacritty-term.svg $out/share/icons/hicolor/scalable/apps/Alacritty.svg
    #
    #     # patchelf generates an ELF that binutils' "strip" doesn't like:
    #     #    strip: not enough room for program headers, try linking with -N
    #     # As a workaround, strip manually before running patchelf.
    #     $STRIP -S $out/bin/alacritty
    #
    #     patchelf --set-rpath "${lib.makeLibraryPath rpathLibs}" $out/bin/alacritty
    #
    #     installShellCompletion --zsh extra/completions/_alacritty
    #     installShellCompletion --bash extra/completions/alacritty.bash
    #     installShellCompletion --fish extra/completions/alacritty.fish
    #
    #     install -dm 755 "$out/share/man/man1"
    #     # gzip -c extra/alacritty.man > "$out/share/man/man1/alacritty.1.gz"
    #     # gzip -c extra/alacritty-msg.man > "$out/share/man/man1/alacritty-msg.1.gz"
    #     scdoc < extra/man/alacritty.1.scd | gzip -c > "$out/share/man/man1/alacritty.1.gz"
    #     scdoc < extra/man/alacritty-msg.1.scd | gzip -c > "$out/share/man/man1/alacritty-msg.1.gz"
    #
    #     install -Dm 644 alacritty.yml $out/share/doc/alacritty.yml
    #
    #     install -dm 755 "$terminfo/share/terminfo/a/"
    #     tic -xe alacritty,alacritty-direct -o "$terminfo/share/terminfo" extra/alacritty.info
    #     mkdir -p $out/nix-support
    #     echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
    #   '';
    # });
    settings = {
      live_config_reload = true;
      # copied from
      # https://github.com/aarowill/base16-alacritty/blob/master/templates/default.mustache
      colors = with config.colorScheme.colors; let
        black   = "0x${base00}";
        blue    = "0x${base0D}";
        cyan    = "0x${base0C}";
        green   = "0x${base0B}";
        grey    = "0x${base03}";
        magenta = "0x${base0E}";
        red     = "0x${base08}";
        white   = "0x${base05}";
        yellow  = "0x${base0A}";
      in {
        primary = {
          background = black;
          foreground = white;
        };
        cursor = {
          text = black;
          cursor = white;
        };
        normal = {
          inherit black blue cyan green magenta red white yellow;
        };
        bright = {
          black = grey;
          inherit blue cyan green magenta red white yellow;
        };
        draw_bold_text_with_bright_colors = false;
      };
      cursor.style = "Underline";
      font = {
        size = 8;
        normal = {
          family = "scientifica";
          style = "Medium";
        };
        bold = {
          family = "scientifica";
          style = "Bold";
        };
        italic = {
          family = "scientifica";
          style = "Italic";
        };
        bold_italic = {
          family = "scientifica";
          style = "Bold";
        };
      };
      window = {
        dynamic_padding = true;
        padding = {
          x = 15;
          y = 15;
        };
      };
      shell = with pkgs; {
        program = "${binPath tmux}";
        args = [
          "-f"
          "${tmuxconf}"
        ];
      };
    };
  };
}
