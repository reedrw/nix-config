{
  lib,
  fetchFromGitHub,
  runtimeShell,
  graphicsmagick,
  callPackage,
  fetchurl,
  runCommand,
  jre,
  jq,

  darkTheme ? false,
  debloat ? true,
  extraOptions ? {}
}:

let
  fetchFromMegaNz = callPackage ./fetchFromMegaNz.nix { };

  src = fetchFromMegaNz {
    name= "JDownloader";
    url = "https://mega.nz/file/nJdklRLT#aGoGo2JDPucYttONaTV5LXd4HgEMNKrKPQzy_LWdsSc";
    sha256="sha256-6k0PYN9XDaTSxaQlgpMh5hLANxC2Vwl0VfEzPq3IkN4=";
  };

  icon = fetchurl {
    url = "https://jdownloader.org/_media/vote/trazo.png";
    sha256 = "3ebab992e7dd04ffcb6c30fee1a7e2b43f3537cb2b22124b30325d25bffdac29";
  };

  darkThemeSrc = fetchFromGitHub {
    owner = "moktavizen";
    repo = "material-darker-jdownloader";
    rev = "f004ca290e903a6732c3be9955b5acaef582a268";
    hash = "sha256-pct3O5jV2X2/Uc17DKICgxh4AMfTMrLv7pTgh9xxRsM=";
  };

  darkThemeOptions = {
    "org.jdownloader.settings.GraphicalUserInterfaceSettings" = {
      lookandfeeltheme = "FLATLAF_DARK";
    };
  };

  # Apply debloating settings from:
  # https://claraiscute.neocities.org/Guides/jdownloader2/
  debloatOptions = {
    "org.jdownloader.settings.GraphicalUserInterfaceSettings" = {
      bannerenabled = false;
      donatebuttonstate = "AUTO_HIDDEN";
      premiumalertetacolumnenabled = false;
      premiumalertspeedcolumnenabled = false;
      premiumalerttaskcolumnenabled = false;
      specialdealoboomdialogvisibleonstartup = false;
      specialdealsenabled = false;
      speedmetervisible = false;
    };
  };

  finalOptions = lib.foldl' (a: x: lib.recursiveUpdate a x) {} [
    (lib.optionalAttrs darkTheme darkThemeOptions)
    (lib.optionalAttrs debloat debloatOptions)
    extraOptions
  ];

  text = ''
    #!${runtimeShell}

    set -o errexit
    set -o nounset
    set -o pipefail

    export PATH=${lib.makeBinPath [ jre jq ]}:$PATH

    if [ ! -d "$XDG_DATA_HOME/jdownloader" ]; then
      mkdir "$XDG_DATA_HOME/jdownloader"
    fi

    if [ ! -f "$XDG_DATA_HOME/jdownloader/JDownloader.jar" ]; then
      install -m 644 ${src}/JDownloader.jar "$XDG_DATA_HOME/jdownloader"
    fi

    if [ ! -d "$XDG_DATA_HOME/jdownloader/cfg" ]; then
      mkdir "$XDG_DATA_HOME/jdownloader/cfg"
    fi
  '' + lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: ''
    if [ -f "$XDG_DATA_HOME/jdownloader/cfg/${n}.json" ]; then
      tmp="$(jq -r '${lib.concatStringsSep "|" (lib.mapAttrsToList (n1: v1: ".${n1}=${builtins.toJSON v1}") v)}' \
        "$XDG_DATA_HOME/jdownloader/cfg/${n}.json"
      )" && cat <<< "$tmp" > "$XDG_DATA_HOME/jdownloader/cfg/${n}.json"
    else
      echo '${builtins.toJSON v}' > "$XDG_DATA_HOME/jdownloader/cfg/${n}.json"
    fi
  '' ) finalOptions) + lib.optionalString darkTheme ''
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
in runCommand "jdownloader" {
  meta = with lib; {
    homepage = "https://jdownloader.org/";
    description = "Free, open-source download management tool";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
    mainProgram = "jdownloader";
  };
} ''
  mkdir -p $out/bin $out/share/applications

  cat << 'EOF' > $out/bin/jdownloader
  ${text}
  EOF

  chmod +x $out/bin/jdownloader

  for size in 16 24 32 48 64 128 256 512; do
    mkdir -p $out/share/icons/hicolor/"$size"x"$size"/apps
    ${lib.getExe graphicsmagick} convert -resize "$size"x"$size" ${icon} $out/share/icons/hicolor/"$size"x"$size"/apps/jdownloader.png
  done

  cat << EOF > $out/share/applications/jdownloader.desktop
  [Desktop Entry]
  Categories=Network
  Comment=Free, open-source download management tool.
  Exec=jdownloader
  GenericName=JDownloader 2
  Icon=jdownloader
  Name=JDownloader 2
  Type=Application
  Version=1.5
  EOF
''
