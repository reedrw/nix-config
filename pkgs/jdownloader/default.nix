{
  symlinkJoin,
  makeDesktopItem,
  graphicsmagick,
  fetchurl,
  callPackage,
  lib,

  darkTheme ? false,
  debloat ? true,
  extraOptions ? {}
}:

let
  icon = fetchurl {
    url = "https://jdownloader.org/_media/vote/trazo.png";
    sha256 = "3ebab992e7dd04ffcb6c30fee1a7e2b43f3537cb2b22124b30325d25bffdac29";
  };

  wrapper = callPackage ./wrapper.nix { inherit darkTheme debloat extraOptions; };
in symlinkJoin {
  name = "jdownloader";

  paths = [
    wrapper
    (makeDesktopItem {
      name = "JDownloader 2";
      exec = "${wrapper}/bin/jdownloader";
      icon = "jdownloader";
      comment = "Free, open-source download management tool.";
      desktopName = "JDownloader 2";
      genericName = "JDownloader 2";
      categories = ["Network"];
    })
  ];

  postBuild = ''
    mkdir -pv $out/bin $out/share/applications

    for size in 16 24 32 48 64 128 256 512; do
      mkdir -p $out/share/icons/hicolor/"$size"x"$size"/apps
      ${lib.getExe graphicsmagick} convert -resize "$size"x"$size" ${icon} $out/share/icons/hicolor/"$size"x"$size"/apps/jdownloader.png
    done
  '';

  meta = with lib; {
    homepage = "https://jdownloader.org/";
    description = "Free, open-source download management tool";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
    mainProgram = "jdownloader";
  };
}
