{
  writeShellApplication,
  python3,
  nix,
}:

writeShellApplication {
  name = "why-diff";

  runtimeInputs = [ nix ];

  text = ''
    exec ${python3}/bin/python3 ${./why-diff.py} "$@"
  '';
}
