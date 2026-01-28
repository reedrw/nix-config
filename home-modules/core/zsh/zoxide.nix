{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  custom.persistence.directories = [
    ".local/share/zoxide"
  ];
}
