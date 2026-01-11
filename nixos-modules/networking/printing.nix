{
  services.printing.enable = true;
  programs.system-config-printer.enable = true;

  custom.persistence.directories = [
    "/var/lib/cups"
  ];
}
