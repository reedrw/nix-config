{
  stdenv,
  writeShellScript,
  writeShellApplication,
  coreutils,
  fetchFromGitHub,
  jq,
  lib,
  megacmd,
  openjdk,
  darkTheme ? false
}:

let
  fetchFromMegaNz = { name, url, sha256, isDir ? false }:
  # isDir: mega.nz allows to download folders
  # with isDir == false, the remote filename is ignored
  # for single files, isDir == true will produce a different sha256 than isDir == false
  stdenv.mkDerivation {
    inherit name;
    outputHashMode = if isDir then "recursive" else "flat";
    outputHashAlgo = "sha256";
    outputHash = sha256;
    builder = writeShellScript "builder.sh" ''
      PATH=${lib.makeBinPath [ megacmd coreutils ]}

      # workaround for https://github.com/meganz/MEGAcmd/issues/580
      export HOME=/tmp/home
      mkdir -p $HOME

      mkdir tmpdir
      cd tmpdir
      mega-get ${url}

      ${
        if isDir
        then ''
          mkdir $out
          mv * $out
        ''
        else ''
          if [ $(ls -A | wc -l) -ne 1 ]; then
            echo "error: isDir is false, but download produced multiple files:"
            ls -A
            exit 1
          fi
          mkdir $out
          cd ..
          mv tmpdir $out
        ''
      }
    '';
    buildInputs = [ megacmd coreutils ];
  };

  src = fetchFromMegaNz {
    name= "JDownloader";
    url = "https://mega.nz/file/3dkXRLTb#tBmI9K0jrbjkh57CArqkVPbmMZ8l11JypDbM8RncqdU";
    sha256="sha256-stMfQwRhng+apYtUaDx7eavP4Zmb3cucISIviVButtQ=";
    isDir = true;
  };

  darkThemeSrc = fetchFromGitHub {
    owner = "moktavizen";
    repo = "material-darker-jdownloader";
    rev = "f004ca290e903a6732c3be9955b5acaef582a268";
    hash = "sha256-pct3O5jV2X2/Uc17DKICgxh4AMfTMrLv7pTgh9xxRsM=";
  };
in writeShellApplication {
  name = "jdownloader";
  runtimeInputs = [ openjdk jq ];
  text = ''
    if [ ! -d "$XDG_DATA_HOME/jdownloader" ]; then
      mkdir "$XDG_DATA_HOME/jdownloader"
    fi

    if [ ! -f "$XDG_DATA_HOME/jdownloader/JDownloader.jar" ]; then
      install -m 644 ${src}/JDownloader.jar "$XDG_DATA_HOME/jdownloader"
    fi

    if [ ! -d "$XDG_DATA_HOME/jdownloader/cfg" ]; then
      mkdir "$XDG_DATA_HOME/jdownloader/cfg"
    fi

    if [ ! -f "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json" ]; then
      (
      echo '{'
      echo '  "premiumalertetacolumnenabled": false,'
      echo '  "premiumalertspeedcolumnenabled": false,'
      echo '  "premiumalerttaskcolumnenabled": false,'
      echo '  "specialdealoboomdialogvisibleonstartup": false,'
      echo '  "specialdealsenabled": false',
      echo '  "donatebuttonstate":"AUTO_HIDDEN",'
      ${lib.optionalString darkTheme ''
          echo '  "lookandfeeltheme":"FLATLAF_DARK",'
      ''}
      echo '  "bannerenabled": false'
      echo '}'
      ) > "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"
    fi

    tmp="$(jq '.donatebuttonstate = "AUTO_HIDDEN"' \
      "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"
    )"

    echo "$tmp" > "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"

    if [ ! -f "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GeneralSettings.json" ]; then
      mkdir "$XDG_DATA_HOME/jdownloader/downloads"
      (
      echo '{'
      echo "  \"defaultdownloadfolder\": \"$XDG_DATA_HOME/jdownloader/downloads\""
      echo '}'
      ) > "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GeneralSettings.json"
    fi

  '' + lib.optionalString darkTheme ''
    tmp="$(jq '.lookandfeeltheme = "FLATLAF_DARK"' \
      "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"
    )"

    echo "$tmp" > "$XDG_DATA_HOME/jdownloader/cfg/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"

    mkdir -p "$XDG_DATA_HOME/jdownloader/themes/standard/org/jdownloader"
    mkdir -p "$XDG_DATA_HOME/jdownloader/libs/laf"

    if [ -d "$XDG_DATA_HOME/jdownloader/themes/standard/org/jdownloader/images" ]; then
      rm -r "$XDG_DATA_HOME/jdownloader/themes/standard/org/jdownloader/images"
      cp -r "${darkThemeSrc}/images" "$XDG_DATA_HOME/jdownloader/themes/standard/org/jdownloader"
      find "$XDG_DATA_HOME/jdownloader/themes/standard/org/jdownloader" -exec chmod u+w {} \;
    fi

    if [ ! -d "$XDG_DATA_HOME/jdownloader/cfg/laf" ]; then
      cp -r "${darkThemeSrc}/laf" "$XDG_DATA_HOME/jdownloader/cfg"
      find "$XDG_DATA_HOME/jdownloader/cfg" -exec chmod u+w {} \;
    fi

    if [ -f "$XDG_DATA_HOME/jdownloader/libs/laf/flatlaf.jar" ]; then
      rm "$XDG_DATA_HOME/jdownloader/libs/laf/flatlaf.jar"
      install "${darkThemeSrc}/flatlaf.jar" "$XDG_DATA_HOME/jdownloader/libs/laf"
    fi

  '' + ''
    java -jar "$XDG_DATA_HOME/jdownloader/JDownloader.jar"
  '';
  meta.mainProgram = "jdownloader";
}
