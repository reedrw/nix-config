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
          rev = "71a06f28551611d192d3e644d95ad04023e10801";
          sha256 = "sha256-Yjdn1oE5VtJMGnmQ2VC764UXKm1PrkIPXXQ8MzQ8u1U=";
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
      mime ^text,  label editor = $EDITOR -- "$@"
    '';

    "ranger/scope.sh".source = pkgs.writeShellScript "scope.sh" (builtins.readFile ./scope.sh);
    "ranger/plugins/ranger-archives".source = sources.ranger-archives;
  };
}
