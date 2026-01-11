{
  services.gnome-keyring.enable = true;

  custom.persistence.directories = [
    ".local/share/keyrings"
  ];
}
