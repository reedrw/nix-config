{
  services.thelounge = {
    enable = true;
    extraConfig = {
      updateCheck = false;
    };
  };

  custom.persistence.directories = [
    "/var/lib/thelounge"
  ];
}
