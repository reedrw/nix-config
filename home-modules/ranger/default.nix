{ lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };

  ccat = with pkgs; writeShellScriptBin "bat" ''
    ${lib.getExe bat} --theme=base16 "$@"
  '';

  rangerlaunch = pkgs.writeShellScript "rangerlaunch" ''
    kitty --session=none ${pkgs.writeShellScript "rangercommand" ''
      cd "$*"
      ranger
      tmux
    ''} $@
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
    tmux
    unrar
    unzip
    xdragon
    zip
  ] ++ (with pkgs.python3Packages; [
    pdf2image
    pillow
  ]);

in
{

  home.packages = let
    ranger = #pkgs.versionConditionalOverride "1.9.3" myranger
      # https://github.com/ranger/ranger/pull/2856
      myranger.overrideAttrs (old: {
        version = "1.9.3";
        src = pkgs.fetchFromGitHub {
          owner = "Ethsan";
          repo = "ranger";
          rev = "c73ffcbad20c6fef688ad0deb8d133ee5826e518";
          sha256 = "sha256-10DyzWdnpXjwsmPEw6V7BTRmYIu+mXHk3sXy4Emn8Nk=";
        };
        propagatedBuildInputs = old.propagatedBuildInputs ++ (with pkgs.python3Packages; [ astroid pylint ]);
      });
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
  in [ ranger ];

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
      set preview_images_method kitty
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
      ext rs = ''${VISUAL:-$EDITOR} -- "$@"
      ext hs = ''${VISUAL:-$EDITOR} -- "$@"
      mime ^text,  label editor = $EDITOR -- "$@"
    '';

    "ranger/scope.sh".source = pkgs.writeShellScript "scope.sh" (builtins.readFile ./scope.sh);
    "ranger/plugins/ranger-archives".source = sources.ranger-archives;
  };
}
