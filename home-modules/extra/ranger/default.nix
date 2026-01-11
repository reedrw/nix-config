{ lib, pkgs, util, ... }:
let
  sources = (util.importFlake ./plugins).inputs;

  ccat = with pkgs; writeShellScriptBin "bat" ''
    ${lib.getExe bat} --color=always --theme=base16-stylix --style='changes,snip,numbers' --paging=never --wrap=never "$@"
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
    loupe
    mediainfo
    poppler-utils
    tmux
    unrar
    p7zip
    unzip
    dragon-drop
    zip
  ] ++ (with pkgs.python3Packages; [
    pdf2image
    pillow
  ]);

in
{

  home.packages = let
    ranger =
      # https://github.com/ranger/ranger/pull/3086
      myranger.overrideAttrs (old: {
        version = "1.9.4";
        src = pkgs.fetchFromGitHub {
          owner = "l4zygreed";
          repo = "ranger";
          rev = "cf078461841ff3dbb0085c48f44f7d5e27f5bfd9";
          sha256 = "sha256-O5ID4c3lJ/1dMQMevikwxDLu6Dg+0DMbiWX4ouo2CnA=";
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
      map D shell dragon-drop -a -x %p
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

    "ranger/scope.sh".source = pkgs.writeShellScript "scope.sh" <| builtins.readFile ./scope.sh;
    "ranger/plugins/ranger-archives".source = sources.ranger-archives;
  };

  custom.persistence.directories = [
    ".cache/ranger"
    ".local/share/ranger"
  ];
}
