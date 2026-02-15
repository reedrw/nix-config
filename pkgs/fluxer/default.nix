{
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  glib,
  nspr,
  nss,
  dbus,
  at-spi2-atk,
  cups,
  cairo,
  gtk3,
  pango,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXtst,
  libXt,
  libXfixes,
  libXrandr,
  libgbm,
  expat,
  libxcb,
  libxkbcommon,
  eudev,
  alsa-lib,
  lib,
  libGL,
  writeText,
  ...
}:
stdenv.mkDerivation {
  pname = "fluxer";
  version = "0.0.8";

  src = builtins.fetchurl {
    url = "https://api.fluxer.app/dl/desktop/stable/linux/x64/fluxer-stable-0.0.8-x64.tar.gz";
    sha256 = "sha256-rPY5j6aBByD+2FsGwBGzJOfbT+xr8vx62TwkRsNgDy0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    glib
    nspr
    nss
    dbus.lib
    at-spi2-atk
    cups.lib
    cairo
    gtk3
    pango
    libX11
    libXcomposite
    libXdamage
    libXext
    libXtst
    libXt
    libXfixes
    libXrandr
    libgbm
    expat
    libxcb
    libxkbcommon
    eudev
    alsa-lib
  ];

  installPhase = ''
    mkdir -p $out/runtime
    mkdir -p $out/bin

    cp -r ./* $out/runtime
    ls -la $out/runtime
    ln -sf $out/runtime/fluxer $out/bin/fluxer

    wrapProgram $out/bin/fluxer \
    --prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        libGL
      ]
    }

    mkdir -p $out/share/applications/
    substitute ${writeText "fluxer.desktop" ''
      [Desktop Entry]
      Name=Fluxer
      Comment=OSS messaging platform
      Exec=@out@/bin/fluxer
      Icon=fluxer
      Terminal=false
      Type=Application
      StartupNotify=true
      StartupWMClass=fluxer
    ''} $out/share/applications/fluxer.desktop --subst-var out



    mkdir -p $out/share/icons/hicolor/512x512/
    cp $out/runtime/resources/512x512.png $out/share/icons/hicolor/512x512/fluxer.png
  '';
}
