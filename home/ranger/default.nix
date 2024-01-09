{ lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };

  ccat = with pkgs; writeShellScriptBin "bat" ''
    ${binPath bat} --theme=base16 "$@"
  '';

  rangercommand = pkgs.writeShellScript "rangercommand" ''
    cd "$*"
    ranger
    $SHELL
  '';

  rangerlaunch = pkgs.writeShellScript "rangerlaunch" ''
    alacritty -e ${rangercommand} $@
  '';

  etouch = pkgs.writeShellScriptBin "etouch" ''
    file="$*"
    touch "$file"
    [[ "''$file*: -3}" == *".sh"* ]] && chmod +x "$file"
  '';

  bins = with pkgs; [
    atool
    ccat
    etouch
    ffmpegthumbnailer
    fontforge
    imagemagick
    jq
    libarchive
    libreoffice
    loupe
    mediainfo
    poppler_utils
    python3Packages.pdf2image
    tmux
    unrar
    unzip
    xdragon
    zip
  ];

in
{

  home.packages = let
    ranger = myranger.override { imagePreviewSupport = false; };
    myranger = pkgs.ranger.overrideAttrs (_: {
      buildInputs = _.buildInputs ++ [ pkgs.makeWrapper ];
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
          --prefix PATH : ${lib.makeBinPath bins}
      '';
    });
  in [
    # TODO: figure out why ueberzugpp tries to create windows
    ranger
    pkgs.pinned.ueberzugpp.v2_8_7
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "ranger.desktop";
  };
  xdg.configFile = {
    "ranger/rc.conf".text = ''
      map D shell dragon -a -x %p
      map S q
      map e console shell etouch%space
      map xc compress
      map xx extract
      set preview_images true
      set use_preview_script true
      set preview_script ~/.config/ranger/scope.sh
      set preview_images_method ueberzug
    '';

    "ranger/rifle.conf".text = ''
      ext doc, flag f = libreoffice "$@"
      ext docx, flag f = libreoffice "$@"
      ext flac = mpv --force-window -- "$@"
      ext wav =  mpv --force-window -- "$@"
      ext ogg =  mpv --force-window -- "$@"
      ext mp3 =  mpv --force-window -- "$@"
      ext gif, flag f = loupe -- "$@"
      ext png, flag f = loupe -- "$@"
      ext jpg, flag f = loupe -- "$@"
      ext jpeg, flag f = loupe -- "$@"
      ext mkv, flag f = mpv -- "$@"
      ext mov, flag f = mpv -- "$@"
      ext mp4, flag f = mpv -- "$@"
      ext pdf, flag f = zathura -- "$@"
      ext webm, flag f = mpv -- "$@"
      ext js = ''${VISUAL:-$EDITOR} -- "$@"
      ext yaml = ''${VISUAL:-$EDITOR} -- "$@"
      ext yml = ''${VISUAL:-$EDITOR} -- "$@"
      ext json = ''${VISUAL:-$EDITOR} -- "$@"
      ext nix = ''${VISUAL:-$EDITOR} -- "$@"
      ext sh = ''${VISUAL:-$EDITOR} -- "$@"
      ext hs = ''${VISUAL:-$EDITOR} -- "$@"
      mime ^text,  label editor = $EDITOR -- "$@"
    '';

    "ranger/scope.sh".source = pkgs.writeShellScript "scope.sh" (builtins.readFile ./scope.sh);
    "ranger/plugins/ranger-archives".source = sources.ranger-archives;
  };
}
