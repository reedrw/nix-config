{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

  ccat = pkgs.writeShellScriptBin "bat"''
    ${pkgs.bat}/bin/bat --theme=base16 "$@"
  '';

  rangercommand = pkgs.writeShellScript "rangercommand"''
    cd $@
    ranger
    $SHELL
  '';

  rangerlaunch = pkgs.writeShellScript "rangerlaunch"''
    urxvtc -e ${rangercommand} $@
  '';


in
{

  home.packages = let
    myranger = pkgs.ranger.overrideAttrs (
      oldAttrs: rec {
        buildInputs = oldAttrs.buildInputs ++ [ pkgs.makeWrapper ];
        postInstall = ''
          cat << EOF > $out/share/applications/ranger.desktop
          [Desktop Entry]
          Type=Application
          Name=ranger
          Comment=Launches the ranger file manager
          Icon=utilities-terminal
          Exec=${rangerlaunch}
          Categories=ConsoleOnly;System;FileTools;FileManager
          MimeType=inode/directory;
          Keywords=File;Manager;Browser;Explorer;Launcher;Vi;Vim;Python
          EOF

          wrapProgram $out/bin/ranger \
            --prefix PATH : ${ccat}/bin \
            --prefix PATH : ${pkgs.atool}/bin \
            --prefix PATH : ${pkgs.dragon-drop}/bin \
            --prefix PATH : ${pkgs.ffmpegthumbnailer}/bin \
            --prefix PATH : ${pkgs.fontforge}/bin \
            --prefix PATH : ${pkgs.imagemagick}/bin \
            --prefix PATH : ${pkgs.jq}/bin \
            --prefix PATH : ${pkgs.libarchive}/bin \
            --prefix PATH : ${pkgs.libreoffice}/bin \
            --prefix PATH : ${pkgs.mediainfo}/bin \
            --prefix PATH : ${pkgs.poppler_utils}/bin \
            --prefix PATH : ${pkgs.python38Packages.pdf2image}/bin \
            --prefix PATH : ${pkgs.ueberzug}/bin \
            --prefix PATH : ${pkgs.unrar}/bin \
            --prefix PATH : ${pkgs.unzip}/bin \
            --prefix PATH : ${pkgs.zip}/bin
        '';
      }
    );
    # imagePreviewSupport uses w3m. I don't need this because I use ueberzug instead
    ranger = myranger.override { imagePreviewSupport = false; };
  in [ ranger ];

  xdg.configFile = {
    "ranger/rc.conf".text = ''
      map e console touch%space
      map D shell dragon -a -x %p
      map ex extract
      map ec compress
      set preview_images true
      set use_preview_script true
      set preview_script ~/.config/ranger/scope.sh
      set preview_images_method ueberzug
    '';

    "ranger/rifle.conf".text = ''
      ext doc, flag f = libreoffice "$@"
      ext docx, flag f = libreoffice "$@"
      ext flac = mpv -- "$@"
      ext wav = mpv -- "$@"
      ext ogg = mpv -- "$@"
      ext mp3 = mpv -- "$@"
      ext gif, flag f = mpv -- "$@"
      ext png, flag f = mpv -- "$@"
      ext jpg, flag f = mpv -- "$@"
      ext mkv, flag f = mpv -- "$@"
      ext mp4, flag f = mpv -- "$@"
      ext pdf, flag f = zathura -- "$@"
      ext webm, flag f = mpv -- "$@"
      ext nix = ''${VISUAL:-$EDITOR} -- "$@"
      ext sh = ''${VISUAL:-$EDITOR} -- "$@"
      mime ^text,  label editor = $EDITOR -- "$@"
    '';

    "ranger/scope.sh".source = pkgs.writeShellScript "scope.sh" (builtins.readFile ./scope.sh);

    "ranger/plugins/compress.py".source = "${sources.ranger-archives}/compress.py";
    "ranger/plugins/extract.py".source = "${sources.ranger-archives}/extract.py";
  };
}

