{
  allowUnfree = true;
  permittedInsecurePackages = [
    # bitwarden-desktop 2026.3.1 requires electron 39, which is EOL but fully patched (39.8.10).
    # Remove once bitwarden upgrades to electron 40+.
    "electron-39.8.10"
  ];
}
