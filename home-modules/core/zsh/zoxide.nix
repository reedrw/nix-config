{
  programs.zoxide = {
    enable = true;
    # integration is sourced from a pre-baked script instead (see ../default.nix)
    enableZshIntegration = false;
  };

  custom.persistence.directories = [
    ".local/share/zoxide"
  ];
}
