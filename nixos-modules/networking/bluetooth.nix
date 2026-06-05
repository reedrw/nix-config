{
  hardware.bluetooth = {
    enable = true;
  };

  programs.librepods.enable = true;

  custom.persistence.directories = [
    "/var/lib/bluetooth"
  ];
}
