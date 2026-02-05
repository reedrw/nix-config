{ stdenv, lib, writeShellScript, megacmd, coreutils }:

{ name, url, sha256, isDir ? false }:

# isDir: mega.nz allows to download folders
# with isDir == false, the remote filename is ignored
# for single files, isDir == true will produce a different sha256 than isDir == false
stdenv.mkDerivation {
  inherit name;
  outputHashMode = "recursive";
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
}
