{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-256"
        "hmac-sha2-512"
      ];
    };
  };

  custom.persistence.directories = [
    "/etc/ssh"
  ];
}
