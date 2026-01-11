{
  security.sudo.extraConfig = ''
    # Prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl.
    Defaults use_pty
  '';

  custom.persistence.directories = [
    "/var/db/sudo"
  ];
}
